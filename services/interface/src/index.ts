import PocketBase, { ClientResponseError } from 'pocketbase';
import { createOpencodeClient } from '@opencode-ai/sdk';
import { EventSource } from 'eventsource';

(globalThis as any).EventSource = EventSource;

// --- Configuration ---
const POCKETBASE_URL = process.env.POCKETBASE_URL || 'http://pocketbase:8090';
const OPENCODE_URL = process.env.OPENCODE_URL || 'http://opencode:3000';
const HEALTH_PORT = parseInt(process.env.HEALTH_PORT || '8080', 10);

const pb = new PocketBase(POCKETBASE_URL);
const oc = createOpencodeClient({ baseUrl: OPENCODE_URL });

// Bounded cache for Session ID -> Chat Record ID
const SESSION_CACHE_MAX = 1000;
const sessionToChat = new Map<string, string>();

function cacheSession(sessionID: string, chatID: string) {
    if (sessionToChat.size >= SESSION_CACHE_MAX) {
        const oldest = sessionToChat.keys().next().value;
        if (oldest) sessionToChat.delete(oldest);
    }
    sessionToChat.set(sessionID, chatID);
}

// Whitelist for Narrative Sync
const NARRATIVE_PART_TYPES = new Set([
    'text',
    'reasoning',
    'tool',
    'file',
    'agent',
    'step-start',
    'step-finish'
]);

// Metadata fields to scrub
const SCRUB_FIELDS = [
    'tokens_consumed',
    'latency_ms',
    'provider_internal_id'
];

function scrubPart(part: any) {
    if (!part.metadata) return part;
    const scrubbedMetadata = { ...part.metadata };
    for (const field of SCRUB_FIELDS) {
        delete scrubbedMetadata[field];
    }
    return { ...part, metadata: scrubbedMetadata };
}

// Per-message update lock (prevents streaming race conditions)
const messageUpdateLocks = new Map<string, Promise<void>>();

async function withMessageLock(messageID: string, fn: () => Promise<void>) {
    const prev = messageUpdateLocks.get(messageID) ?? Promise.resolve();
    const next = prev.then(fn, fn);
    messageUpdateLocks.set(messageID, next);
    try {
        await next;
    } finally {
        if (messageUpdateLocks.get(messageID) === next) {
            messageUpdateLocks.delete(messageID);
        }
    }
}

// Provider sync interval handle
let providerSyncInterval: ReturnType<typeof setInterval> | null = null;
const PROVIDER_SYNC_INTERVAL_MS = 24 * 60 * 60 * 1000; // 24 hours

// Pump status tracking for health check
let eventPumpHealthy = false;
let commandPumpHealthy = false;

/**
 * OPENCODE -> POCKETBASE (Event Pump)
 */
let reconnectDelay = 1000;
const MAX_RECONNECT_DELAY = 60000;

async function startEventPump() {
    console.log('[Interface] Starting OpenCode Event Pump...');

    try {
        const subscription = await oc.event.subscribe();
        reconnectDelay = 1000; // Reset on successful connection
        eventPumpHealthy = true;

        for await (const event of (subscription as any).stream) {
            const { type, properties } = event;

            if (type === 'message.part.updated') {
                await handleMessagePartUpdated(properties);
            } else if (type === 'message.updated') {
                await handleMessageCompletion(properties);
            } else if (type === 'permission.updated') {
                await handlePermissionUpdated(properties);
            }
            // NOTE: OpenCode questions arrive as regular assistant messages via message.updated events
        }
    } catch (err) {
        console.error('[Interface] Event Pump Error:', err);
        eventPumpHealthy = false;
        const jitter = Math.random() * 1000;
        const delay = Math.min(reconnectDelay + jitter, MAX_RECONNECT_DELAY);
        console.log(`[Interface] Reconnecting event pump in ${Math.round(delay)}ms...`);
        setTimeout(startEventPump, delay);
        reconnectDelay = Math.min(reconnectDelay * 2, MAX_RECONNECT_DELAY);
    }
}

async function handleMessagePartUpdated(properties: any) {
    const { part, delta } = properties;
    const messageID = part.messageID;
    const sessionID = part.sessionID;
    const chatID = await resolveChatID(sessionID);
    if (!chatID) return;

    let msgRecord = await findMessageByEngineId(messageID);

    if (!msgRecord) {
        try {
            msgRecord = await pb.collection('messages').create({
                chat: chatID,
                role: 'assistant',
                ai_engine_message_id: messageID,
                engine_message_status: 'processing',
                parts: []
            });
        } catch (err) {
            // Another event may have created this record concurrently
            msgRecord = await findMessageByEngineId(messageID);
            if (!msgRecord) throw err;
        }
    }

    await withMessageLock(messageID, async () => {
        const fresh = await pb.collection('messages').getOne(msgRecord.id);
        let parts = Array.isArray(fresh.parts) ? [...fresh.parts] : [];

        if (delta) {
            // Streaming text delta — append to existing part or create new one
            let target = parts.find((p: any) => p.id === part.id);
            if (!target) {
                target = { id: part.id, type: 'text', text: '' };
                parts.push(target);
            }
            target.text = (target.text || '') + delta;
        } else if (NARRATIVE_PART_TYPES.has(part.type)) {
            // Full part upsert
            const processed = scrubPart(part);
            const idx = parts.findIndex((p: any) => p.id === part.id);
            if (idx !== -1) parts[idx] = processed;
            else parts.push(processed);
        }

        await pb.collection('messages').update(msgRecord.id, { parts });
    });
}

async function handleMessageCompletion(properties: any) {
    const message = properties.info;
    if (message.role !== 'assistant') return;

    const msgRecord = await findMessageByEngineId(message.id);
    if (!msgRecord) return;

    let status = 'processing';
    if (message.error) status = 'failed';
    else if (message.time?.completed) status = 'completed';

    await pb.collection('messages').update(msgRecord.id, {
        engine_message_status: status
    });
}

async function handlePermissionUpdated(permission: any) {
    const chatID = await resolveChatID(permission.sessionID);
    if (!chatID) return;

    try {
        await pb.collection('permissions').create({
            ai_engine_permission_id: permission.id,
            session_id: permission.sessionID,
            chat: chatID,
            permission: permission.type,
            message: permission.title,
            patterns: permission.pattern,
            metadata: permission.metadata,
            message_id: permission.messageID,
            call_id: permission.callID,
            status: 'draft'
        });
        console.log(`[Interface] Permission requested: ${permission.id}`);
    } catch (err) {
        console.error('[Interface] Failed to sync permission:', err);
    }
}

/**
 * POCKETBASE -> OPENCODE (Command Pump)
 */
async function startCommandPump() {
    console.log('[Interface] Starting PocketBase Command Pump...');

    // 1. New Messages
    pb.collection('messages').subscribe('*', async (e: any) => {
        if (e.action === 'create' && e.record.role === 'user' && !e.record.ai_engine_message_id) {
            await handleUserMessage(recordToInput(e.record));
        }
    });

    // 2. Permission Responses
    pb.collection('permissions').subscribe('*', async (e: any) => {
        if (e.action === 'update' && (e.record.status === 'authorized' || e.record.status === 'denied')) {
            await handlePermissionReply(e.record);
        }
    });

    // 3. LLM Config Changes (model switching)
    pb.collection('llm_config').subscribe('*', async (e: any) => {
        if (e.action === 'create' || e.action === 'update') {
            await handleModelSwitch(e.record);
        }
    });

    commandPumpHealthy = true;
}

function recordToInput(record: any) {
    const parts = Array.isArray(record.parts) ? record.parts : [];
    const text = parts
        .filter((p: any) => p.type === 'text')
        .map((p: any) => p.text || '')
        .join('\n');
    return { id: record.id, chat: record.chat, text };
}

async function handleUserMessage(input: any) {
    const chat = await pb.collection('chats').getOne(input.chat);
    let sessionID = chat.ai_engine_session_id;

    if (!sessionID) {
        const result = await oc.session.create({ query: { directory: '/workspace' } });
        sessionID = (result.data as any).id;
        await pb.collection('chats').update(chat.id, { ai_engine_session_id: sessionID });
    }

    await oc.session.prompt({
        path: { id: sessionID },
        body: { parts: [{ type: 'text', text: input.text }] }
    });
}

async function handlePermissionReply(record: any) {
    console.log(`[Interface] Replying to permission: ${record.ai_engine_permission_id} -> ${record.status}`);
    const response: 'always' | 'reject' = record.status === 'authorized' ? 'always' : 'reject';

    try {
        await oc.postSessionIdPermissionsPermissionId({
            path: {
                id: record.session_id,
                permissionID: record.ai_engine_permission_id
            },
            body: { response }
        });
        console.log('[Interface] Permission decision sent');
    } catch (err) {
        console.error('[Interface] Permission reply failed:', err);
    }
}

/**
 * LLM PROVIDER SYNC (OpenCode -> PocketBase)
 */
async function syncProviders() {
    console.log('[Interface] Syncing LLM providers from OpenCode...');
    try {
        const result = await oc.provider.list();
        const data = result.data as any;
        const providers: any[] = data?.all ?? [];
        const connectedIds: string[] = data?.connected ?? [];
        const connectedSet = new Set(connectedIds);

        for (const provider of providers) {
            const pid = provider.id;
            const record = {
                provider_id: pid,
                name: provider.name || pid,
                env_vars: provider.env ?? [],
                models: provider.models ?? {},
                is_connected: connectedSet.has(pid),
            };
            try {
                const existing = await pb.collection('llm_providers').getFirstListItem(
                    pb.filter('provider_id = {:pid}', { pid })
                );
                await pb.collection('llm_providers').update(existing.id, record);
            } catch (err) {
                if (err instanceof ClientResponseError && err.status === 404) {
                    await pb.collection('llm_providers').create(record);
                } else {
                    console.error(`[Interface] Failed to sync provider '${pid}':`, err);
                }
            }
        }
        console.log(`[Interface] Synced ${providers.length} LLM providers (${connectedIds.length} connected)`);
    } catch (err) {
        console.error('[Interface] Provider sync failed:', err);
    }
}

/**
 * LLM MODEL SWITCH (PocketBase -> OpenCode)
 */
async function handleModelSwitch(record: any) {
    const model = record.model;
    const chatId = record.chat;

    if (chatId) {
        // Per-chat model switch: find the session and send command
        try {
            const chat = await pb.collection('chats').getOne(chatId);
            const sessionID = chat.ai_engine_session_id;
            if (!sessionID) {
                console.log(`[Interface] Chat ${chatId} has no session, skipping model switch`);
                return;
            }
            await oc.session.command({
                path: { id: sessionID },
                body: { command: 'model', arguments: model }
            });
            console.log(`[Interface] Switched model to '${model}' for session ${sessionID}`);
        } catch (err) {
            console.error(`[Interface] Per-chat model switch failed for chat ${chatId}:`, err);
        }
    } else {
        // Global default model switch
        try {
            await oc.config.update({ body: { model } });
            console.log(`[Interface] Updated global default model to '${model}'`);
        } catch (err) {
            console.error('[Interface] Global model switch failed:', err);
        }
    }
}

// --- Utilities ---

async function resolveChatID(sessionID: string): Promise<string | null> {
    if (sessionToChat.has(sessionID)) return sessionToChat.get(sessionID)!;
    try {
        const chat = await pb.collection('chats').getFirstListItem(
            pb.filter('ai_engine_session_id = {:id}', { id: sessionID })
        );
        cacheSession(sessionID, chat.id);
        return chat.id;
    } catch (err) {
        if (err instanceof ClientResponseError && err.status === 404) return null;
        console.error('[Interface] Failed to resolve chat ID:', err);
        throw err;
    }
}

async function findMessageByEngineId(engineID: string): Promise<any> {
    try {
        return await pb.collection('messages').getFirstListItem(
            pb.filter('ai_engine_message_id = {:id}', { id: engineID })
        );
    } catch (err) {
        if (err instanceof ClientResponseError && err.status === 404) return null;
        console.error('[Interface] Failed to find message by engine ID:', err);
        throw err;
    }
}

// --- Health Check ---

function startHealthCheck() {
    Bun.serve({
        port: HEALTH_PORT,
        fetch(req: Request) {
            const url = new URL(req.url);
            if (url.pathname === '/healthz') {
                const healthy = eventPumpHealthy && commandPumpHealthy;
                return new Response(JSON.stringify({
                    status: healthy ? 'ok' : 'degraded',
                    eventPump: eventPumpHealthy ? 'connected' : 'disconnected',
                    commandPump: commandPumpHealthy ? 'connected' : 'disconnected',
                    sessionCacheSize: sessionToChat.size
                }), {
                    status: healthy ? 200 : 503,
                    headers: { 'Content-Type': 'application/json' }
                });
            }
            return new Response('Not Found', { status: 404 });
        }
    });
    console.log(`[Interface] Health check listening on port ${HEALTH_PORT}`);
}

// --- Graceful Shutdown ---

function setupGracefulShutdown() {
    const shutdown = async () => {
        console.log('[Interface] Shutting down gracefully...');
        try {
            pb.collection('messages').unsubscribe('*');
            pb.collection('permissions').unsubscribe('*');
            pb.collection('llm_config').unsubscribe('*');
            if (providerSyncInterval) clearInterval(providerSyncInterval);
        } catch (err) {
            console.error('[Interface] Error during unsubscribe:', err);
        }
        process.exit(0);
    };
    process.on('SIGTERM', shutdown);
    process.on('SIGINT', shutdown);
}

// --- Start ---
(async () => {
    const agentEmail = process.env.AGENT_EMAIL;
    const agentPass = process.env.AGENT_PASSWORD;

    if (!agentEmail || !agentPass) {
        console.error('[Interface] AGENT_EMAIL and AGENT_PASSWORD environment variables are required');
        process.exit(1);
    }

    try {
        console.log(`[Interface] Authenticating as Agent (${agentEmail})...`);
        await pb.collection('users').authWithPassword(agentEmail, agentPass);
        console.log('[Interface] Agent authenticated!');

        // Auth token refresh hook — re-authenticates when token expires
        let refreshingAuth = false;
        pb.beforeSend = async function (url, options) {
            if (!pb.authStore.isValid && !refreshingAuth) {
                refreshingAuth = true;
                try {
                    console.log('[Interface] Auth token expired, refreshing...');
                    await pb.collection('users').authWithPassword(agentEmail, agentPass);
                } finally {
                    refreshingAuth = false;
                }
            }
            return { url, options };
        };

        // Pre-cache active sessions
        const chats = await pb.collection('chats').getFullList({ filter: 'ai_engine_session_id != ""' });
        for (const chat of chats) {
            cacheSession(chat.ai_engine_session_id, chat.id);
        }
        console.log(`[Interface] Pre-cached ${sessionToChat.size} active sessions`);

        setupGracefulShutdown();
        startHealthCheck();
        startEventPump();
        startCommandPump();

        // Initial provider sync + daily refresh
        syncProviders();
        providerSyncInterval = setInterval(syncProviders, PROVIDER_SYNC_INTERVAL_MS);
    } catch (err) {
        console.error('[Interface] Initialization failed:', err);
        process.exit(1);
    }
})();
