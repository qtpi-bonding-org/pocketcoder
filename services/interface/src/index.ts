import PocketBase from 'pocketbase';
import { createOpencodeClient } from '@opencode-ai/sdk';
import { EventSource } from 'eventsource';

// @ts-ignore
global.EventSource = EventSource;

// --- Configuration ---
const POCKETBASE_URL = process.env.POCKETBASE_URL || 'http://pocketbase:8090';
const OPENCODE_URL = process.env.OPENCODE_URL || 'http://opencode:3000';

const pb = new PocketBase(POCKETBASE_URL);
const oc = createOpencodeClient({ baseUrl: OPENCODE_URL });

// Cache for Session ID -> Chat Record ID
const sessionToChat = new Map<string, string>();

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

/**
 * 🛰️ OPENCODE -> POCKETBASE (Event Pump)
 */
async function startEventPump() {
    console.log('🔌 [Interface] Starting OpenCode Event Pump...');

    try {
        const events = await oc.event.subscribe();
        // @ts-ignore
        for await (const event of events.stream) {
            const { type, data } = event;

            if (type === 'heartbeat') continue;

            if (type === 'message.part.updated' || type === 'message.part.delta') {
                await handleMessageUpdate(data);
            }

            if (type === 'message.updated') {
                await handleMessageCompletion(data);
            }

            if (type === 'question.asked') {
                await handleQuestionAsked(data);
            }

            if (type === 'permission.asked') {
                await handlePermissionAsked(data);
            }
        }
    } catch (err) {
        console.error('❌ [Interface] Event Pump Error:', err);
        setTimeout(startEventPump, 5000);
    }
}

async function handleMessageUpdate(data: any) {
    const { messageID, sessionID, part, delta } = data;
    const chatID = await resolveChatID(sessionID);
    if (!chatID) return;

    let msgRecord = await findMessageByEngineId(messageID);

    if (!msgRecord) {
        msgRecord = await pb.collection('messages').create({
            chat: chatID,
            role: 'assistant',
            ai_engine_message_id: messageID,
            engine_message_status: 'processing',
            parts: []
        });
    }

    let parts = Array.isArray(msgRecord.parts) ? msgRecord.parts : [];

    if (data.type === 'message.part.delta' && delta) {
        const partID = data.partID;
        let targetPart = parts.find((p: any) => p.id === partID);
        if (!targetPart) {
            targetPart = { id: partID, type: 'text', text: '' };
            parts.push(targetPart);
        }
        targetPart.text = (targetPart.text || '') + delta;
    } else if (part) {
        if (NARRATIVE_PART_TYPES.has(part.type)) {
            const processedPart = scrubPart(part);
            const index = parts.findIndex((p: any) => p.id === part.id);
            if (index !== -1) {
                parts[index] = processedPart;
            } else {
                parts.push(processedPart);
            }
        }
    }

    await pb.collection('messages').update(msgRecord.id, { parts });
}

async function handleMessageCompletion(data: any) {
    const { id, status } = data;
    const msgRecord = await findMessageByEngineId(id);
    if (msgRecord) {
        await pb.collection('messages').update(msgRecord.id, {
            engine_message_status: status === 'completed' ? 'completed' : 'failed'
        });
    }
}

async function handleQuestionAsked(data: any) {
    const { id, sessionID, question } = data;
    const chatID = await resolveChatID(sessionID);
    if (!chatID) return;

    try {
        await pb.collection('questions').create({
            id: id,
            chat: chatID,
            question: question.text,
            choices: question.choices,
            status: 'asked'
        });
        console.log(`❓ [Interface] Question synced: ${id}`);
    } catch (err) {
        console.error(`❌ [Interface] Failed to sync question:`, err);
    }
}

async function handlePermissionAsked(data: any) {
    const { id, sessionID, permission, message } = data;
    const chatID = await resolveChatID(sessionID);
    if (!chatID) return;

    try {
        await pb.collection('permissions').create({
            ai_engine_permission_id: id,
            session_id: sessionID,
            chat: chatID,
            permission: permission,
            message: message,
            status: 'draft'
        });
        console.log(`🛡️ [Interface] Permission requested: ${id}`);
    } catch (err) {
        console.error(`❌ [Interface] Failed to sync permission:`, err);
    }
}

/**
 * 📥 POCKETBASE -> OPENCODE (Command Pump)
 */
async function startCommandPump() {
    console.log('🪝 [Interface] Starting PocketBase Command Pump...');

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

    // 3. Question Responses
    pb.collection('questions').subscribe('*', async (e: any) => {
        if (e.action === 'update' && e.record.status === 'replied') {
            await handleQuestionReply(e.record);
        }
    });
}

function recordToInput(record: any) {
    return {
        id: record.id,
        chat: record.chat,
        text: record.text || record.content || ''
    };
}

async function handleUserMessage(input: any) {
    const chat = await pb.collection('chats').getOne(input.chat);
    let sessionID = chat.ai_engine_session_id;

    if (!sessionID) {
        const session = await oc.session.create({ body: { directory: '/workspace' } });
        // @ts-ignore
        sessionID = session.data.id;
        await pb.collection('chats').update(chat.id, { ai_engine_session_id: sessionID });
    }

    await oc.session.prompt({
        path: { id: sessionID },
        body: { parts: [{ type: 'text', text: input.text }] }
    });
}

async function handlePermissionReply(record: any) {
    console.log(`📡 [Interface] Replying to permission: ${record.ai_engine_permission_id} -> ${record.status}`);
    const decision = record.status === 'authorized' ? 'allow' : 'deny';

    try {
        // @ts-ignore
        await oc.session.permissions.postByPermissionId({
            path: {
                id: record.session_id,
                permissionId: record.ai_engine_permission_id
            },
            body: { decision }
        });
        console.log(`✅ [Interface] Permission decision sent`);
    } catch (err) {
        console.error('❌ [Interface] Permission reply failed:', err);
    }
}

async function handleQuestionReply(record: any) {
    console.log(`📡 [Interface] Replying to question: ${record.id} -> ${record.reply}`);
    const chat = await pb.collection('chats').getOne(record.chat);
    const sessionID = chat.ai_engine_session_id;

    try {
        // @ts-ignore
        await oc.session.question.reply({
            path: { id: sessionID, questionId: record.id },
            body: { answer: record.reply }
        });
    } catch (err) {
        console.error('❌ [Interface] Question reply failed:', err);
    }
}

// --- Utilities ---

async function resolveChatID(sessionID: string): Promise<string | null> {
    if (sessionToChat.has(sessionID)) return sessionToChat.get(sessionID)!;
    try {
        const chat = await pb.collection('chats').getFirstListItem(`ai_engine_session_id="${sessionID}"`);
        sessionToChat.set(sessionID, chat.id);
        return chat.id;
    } catch (err) {
        return null;
    }
}

async function findMessageByEngineId(engineID: string) {
    try {
        return await pb.collection('messages').getFirstListItem(`ai_engine_message_id="${engineID}"`);
    } catch (err) {
        return null;
    }
}

// 🚀 Start
(async () => {
    try {
        const agentEmail = process.env.AGENT_EMAIL || 'poco@pocketcoder.local';
        const agentPass = process.env.AGENT_PASSWORD || 'pYlyUIobsSVLzfK1tDD9Ugu4KB/DMA+E';

        // Auth as Agent for Narrative Sync
        console.log(`🔐 [Interface] Authenticating as Agent (${agentEmail})...`);
        await pb.collection('users').authWithPassword(agentEmail, agentPass);
        console.log('🚀 [Interface] Agent authenticated!');

        const chats = await pb.collection('chats').getFullList({ filter: 'ai_engine_session_id != ""' });
        for (const chat of chats) {
            sessionToChat.set(chat.ai_engine_session_id, chat.id);
        }
        console.log(`🔦 [Interface] Pre-cached ${sessionToChat.size} active sessions`);

        startEventPump();
        startCommandPump();
    } catch (err) {
        console.error('❌ [Interface] Initialization failed:', err);
    }
})();
