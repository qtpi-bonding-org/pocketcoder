/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: Interface Bridge. Event pump + command pump syncing PocketBase with OpenCode.
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

// Collection names
const Collections = {
    MESSAGES: 'messages',
    CHATS: 'chats',
    PERMISSIONS: 'permissions',
    MODEL_SELECTION: 'model_selection',
    LLM_PROVIDERS: 'llm_providers',
    USERS: 'users',
} as const;

// Status values
const Status = {
    DRAFT: 'draft',
    PROCESSING: 'processing',
    COMPLETED: 'completed',
    FAILED: 'failed',
    AUTHORIZED: 'authorized',
    DENIED: 'denied',
    PENDING: 'pending',
} as const;

// OpenCode event types
const EventType = {
    MESSAGE_PART_UPDATED: 'message.part.updated',
    MESSAGE_UPDATED: 'message.updated',
    PERMISSION_UPDATED: 'permission.updated',
} as const;

// PocketBase record types (minimal shape for interface needs)
interface PbRecord {
    id: string;
    [key: string]: any;
}

interface ChatRecord extends PbRecord {
    ai_engine_session_id: string;
    user: string;
    agent?: string;
}

interface MessageRecord extends PbRecord {
    chat: string;
    role: string;
    parts: MessagePart[];
    ai_engine_message_id?: string;
    engine_message_status?: string;
    user_message_status?: string;
}

interface MessagePart {
    id?: string;
    type: string;
    text?: string;
    metadata?: Record<string, any>;
    [key: string]: any;
}

interface PermissionRecord extends PbRecord {
    ai_engine_permission_id: string;
    session_id: string;
    chat: string;
    status: string;
    permission: string;
}

interface ModelSelectionRecord extends PbRecord {
    model: string;
    chat?: string;
}

interface UserMessageInput {
    id: string;
    chat: string;
    text: string;
}

// OpenCode event types
interface OcEventProperties {
    part?: any;
    delta?: string;
    info?: any;
}

interface OcPermission {
    id: string;
    sessionID: string;
    type: string;
    title: string;
    pattern: string;
    metadata: any;
    messageID: string;
    callID: string;
}

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

function scrubPart(part: MessagePart): MessagePart {
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

            if (type === EventType.MESSAGE_PART_UPDATED) {
                await handleMessagePartUpdated(properties);
            } else if (type === EventType.MESSAGE_UPDATED) {
                await handleMessageCompletion(properties);
            } else if (type === EventType.PERMISSION_UPDATED) {
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

async function handleMessagePartUpdated(properties: OcEventProperties) {
    const { part, delta } = properties;
    const messageID = part.messageID;
    const sessionID = part.sessionID;
    const chatID = await resolveChatID(sessionID);
    if (!chatID) return;

    let msgRecord = await findMessageByEngineId(messageID);

    if (!msgRecord) {
        try {
            msgRecord = await pb.collection(Collections.MESSAGES).create({
                chat: chatID,
                role: 'assistant',
                ai_engine_message_id: messageID,
                engine_message_status: Status.PROCESSING,
                parts: []
            });
        } catch (err) {
            // Another event may have created this record concurrently
            msgRecord = await findMessageByEngineId(messageID);
            if (!msgRecord) throw err;
        }
    }

    await withMessageLock(messageID, async () => {
        const fresh = await pb.collection(Collections.MESSAGES).getOne(msgRecord.id);
        let parts: MessagePart[] = Array.isArray(fresh.parts) ? [...fresh.parts] : [];

        if (delta) {
            // Streaming text delta — append to existing part or create new one
            let target = parts.find((p: MessagePart) => p.id === part.id);
            if (!target) {
                target = { id: part.id, type: 'text', text: '' };
                parts.push(target);
            }
            target.text = (target.text || '') + delta;
        } else if (NARRATIVE_PART_TYPES.has(part.type)) {
            // Full part upsert
            const processed = scrubPart(part);
            const idx = parts.findIndex((p: MessagePart) => p.id === part.id);
            if (idx !== -1) parts[idx] = processed;
            else parts.push(processed);
        }

        await pb.collection(Collections.MESSAGES).update(msgRecord.id, { parts });
    });
}

async function handleMessageCompletion(properties: OcEventProperties) {
    const message = properties.info;
    if (message.role !== 'assistant') return;

    const msgRecord = await findMessageByEngineId(message.id);
    if (!msgRecord) return;

    let status: string = Status.PROCESSING;
    if (message.error) status = Status.FAILED;
    else if (message.time?.completed) status = Status.COMPLETED;

    await pb.collection(Collections.MESSAGES).update(msgRecord.id, {
        engine_message_status: status
    });

    // Send push notification for terminal states (task_complete / task_error)
    if (status === Status.COMPLETED || status === Status.FAILED) {
        await sendTaskNotification(message.sessionID, status);
    }
}

async function sendTaskNotification(sessionID: string, status: string) {
    try {
        const chatID = await resolveChatID(sessionID);
        if (!chatID) return;

        const chat = await pb.collection(Collections.CHATS).getOne(chatID);
        const userID = chat.user;
        if (!userID) return;

        const notifType = status === Status.COMPLETED ? 'task_complete' : 'task_error';
        const title = status === Status.COMPLETED ? 'Task Complete' : 'Task Error';
        const message = status === Status.COMPLETED
            ? 'Your coding task has finished'
            : 'Your coding task encountered an error';

        await pb.send('/api/pocketcoder/push', {
            method: 'POST',
            body: { user_id: userID, title, message, type: notifType, chat: chatID }
        });
        console.log(`[Interface] Push notification sent: ${notifType} for chat ${chatID}`);
    } catch (err) {
        // Non-fatal — don't crash the event pump over a notification failure
        console.error('[Interface] Push notification failed:', err);
    }
}

async function handlePermissionUpdated(permission: OcPermission) {
    const chatID = await resolveChatID(permission.sessionID);
    if (!chatID) return;

    try {
        await pb.collection(Collections.PERMISSIONS).create({
            ai_engine_permission_id: permission.id,
            session_id: permission.sessionID,
            chat: chatID,
            permission: permission.type,
            message: permission.title,
            patterns: permission.pattern,
            metadata: permission.metadata,
            message_id: permission.messageID,
            call_id: permission.callID,
            status: Status.DRAFT
        });
        console.log(`[Interface] Permission requested: ${permission.id}`);
    } catch (err) {
        console.error('[Interface] Failed to sync permission:', err);
    }
}

/**
 * POCKETBASE -> OPENCODE (Command Pump)
 */
let commandPumpReconnectDelay = 1000;

async function startCommandPump() {
    console.log('[Interface] Starting PocketBase Command Pump...');

    try {
        // Unsubscribe first to avoid duplicate subscriptions on reconnect
        try {
            pb.collection(Collections.MESSAGES).unsubscribe('*');
            pb.collection(Collections.PERMISSIONS).unsubscribe('*');
            pb.collection(Collections.MODEL_SELECTION).unsubscribe('*');
        } catch (_) { /* ignore if not yet subscribed */ }

        // 1. New Messages
        await pb.collection(Collections.MESSAGES).subscribe('*', async (e: { action: string; record: MessageRecord }) => {
            try {
                if (e.action === 'create' && e.record.role === 'user' && !e.record.ai_engine_message_id) {
                    await handleUserMessage(recordToInput(e.record));
                }
            } catch (err) {
                console.error('[Interface] Error handling message subscription event:', err);
            }
        });

        // 2. Permission Responses
        await pb.collection(Collections.PERMISSIONS).subscribe('*', async (e: { action: string; record: PermissionRecord }) => {
            try {
                if (e.action === 'update' && (e.record.status === Status.AUTHORIZED || e.record.status === Status.DENIED)) {
                    await handlePermissionReply(e.record);
                }
            } catch (err) {
                console.error('[Interface] Error handling permission subscription event:', err);
            }
        });

        // 3. LLM Config Changes (model switching)
        await pb.collection(Collections.MODEL_SELECTION).subscribe('*', async (e: { action: string; record: ModelSelectionRecord }) => {
            try {
                if (e.action === 'create' || e.action === 'update') {
                    await handleModelSwitch(e.record);
                }
            } catch (err) {
                console.error('[Interface] Error handling model selection subscription event:', err);
            }
        });

        commandPumpHealthy = true;
        commandPumpReconnectDelay = 1000; // Reset on success
        console.log('[Interface] Command Pump subscriptions established');
    } catch (err) {
        console.error('[Interface] Command Pump subscription failed:', err);
        commandPumpHealthy = false;
        const jitter = Math.random() * 1000;
        const delay = Math.min(commandPumpReconnectDelay + jitter, MAX_RECONNECT_DELAY);
        console.log(`[Interface] Reconnecting command pump in ${Math.round(delay)}ms...`);
        setTimeout(startCommandPump, delay);
        commandPumpReconnectDelay = Math.min(commandPumpReconnectDelay * 2, MAX_RECONNECT_DELAY);
    }
}

function recordToInput(record: MessageRecord): UserMessageInput {
    const parts: MessagePart[] = Array.isArray(record.parts) ? record.parts : [];
    const text = parts
        .filter((p: MessagePart) => p.type === 'text')
        .map((p: MessagePart) => p.text || '')
        .join('\n');
    return { id: record.id, chat: record.chat, text };
}

async function handleUserMessage(input: UserMessageInput) {
    try {
        const chat = await pb.collection(Collections.CHATS).getOne(input.chat);
        let sessionID = chat.ai_engine_session_id;

        if (!sessionID) {
            const result = await oc.session.create({ query: { directory: '/workspace' } });
            sessionID = (result.data as any).id;
            await pb.collection(Collections.CHATS).update(chat.id, { ai_engine_session_id: sessionID });
        }

        await oc.session.prompt({
            path: { id: sessionID },
            body: { parts: [{ type: 'text', text: input.text }] }
        });
    } catch (err) {
        console.error(`[Interface] Failed to handle user message (chat: ${input.chat}):`, err);
    }
}

async function handlePermissionReply(record: PermissionRecord) {
    console.log(`[Interface] Replying to permission: ${record.ai_engine_permission_id} -> ${record.status}`);
    const response: 'always' | 'reject' = record.status === Status.AUTHORIZED ? 'always' : 'reject';

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
                const existing = await pb.collection(Collections.LLM_PROVIDERS).getFirstListItem(
                    pb.filter('provider_id = {:pid}', { pid })
                );
                await pb.collection(Collections.LLM_PROVIDERS).update(existing.id, record);
            } catch (err) {
                if (err instanceof ClientResponseError && err.status === 404) {
                    await pb.collection(Collections.LLM_PROVIDERS).create(record);
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
async function handleModelSwitch(record: ModelSelectionRecord) {
    const model = record.model;
    const chatId = record.chat;

    if (chatId) {
        // Per-chat model switch: find the session and send command
        try {
            const chat = await pb.collection(Collections.CHATS).getOne(chatId);
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
        const chat = await pb.collection(Collections.CHATS).getFirstListItem(
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

async function findMessageByEngineId(engineID: string): Promise<MessageRecord | null> {
    try {
        return await pb.collection(Collections.MESSAGES).getFirstListItem(
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
            pb.collection(Collections.MESSAGES).unsubscribe('*');
            pb.collection(Collections.PERMISSIONS).unsubscribe('*');
            pb.collection(Collections.MODEL_SELECTION).unsubscribe('*');
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
        await pb.collection(Collections.USERS).authWithPassword(agentEmail, agentPass);
        console.log('[Interface] Agent authenticated!');

        // Auth token refresh hook — re-authenticates when token expires
        let refreshPromise: Promise<void> | null = null;
        pb.beforeSend = async function (url, options) {
            if (!pb.authStore.isValid) {
                if (!refreshPromise) {
                    refreshPromise = pb.collection(Collections.USERS).authWithPassword(agentEmail, agentPass)
                        .then(() => { refreshPromise = null; })
                        .catch((err) => {
                            refreshPromise = null;
                            console.error('[Interface] Auth refresh failed:', err);
                        });
                }
                await refreshPromise;
            }
            return { url, options };
        };

        // Pre-cache active sessions
        const chats = await pb.collection(Collections.CHATS).getFullList({ filter: 'ai_engine_session_id != ""' });
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
