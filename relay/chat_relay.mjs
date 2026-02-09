#!/usr/bin/env node
/**
 * 🌉 POCKETCODER CHAT RELAY (SDK VERSION)
 * 
 * This service relays between PocketBase and OpenCode using the PocketBase JS SDK:
 * 1. Subscribes to new user messages in PocketBase (Realtime)
 * 2. Catches up on missed messages on startup (Recovery)
 * 3. Sends them to OpenCode via REST API
 * 4. Streams responses back to PocketBase for the UI
 */

import PocketBase from 'pocketbase';
import { EventSource } from 'eventsource';
import fs from 'fs/promises';
import path from 'path';

// Required for PocketBase Realtime in Node.js
global.EventSource = EventSource;

const POCKETBASE_URL = process.env.POCKETBASE_URL || "http://pocketbase:8090";
const OPENCODE_URL = process.env.OPENCODE_URL || "http://opencode:3000";
const AGENT_EMAIL = process.env.AGENT_EMAIL || 'agent@pocketcoder.local';
const AGENT_PASSWORD = process.env.AGENT_PASSWORD || 'EJ6IiRKdHR8Do6IogD7PApyErxDZhUmp';

const pb = new PocketBase(POCKETBASE_URL);
let currentChatId = null;
const sessionToChat = new Map(); // sessionID -> chatId

console.log("🌉 [Chat Relay] Starting Realtime Relay...");
console.log(`   PocketBase: ${POCKETBASE_URL}`);
console.log(`   OpenCode: ${OPENCODE_URL}`);

/**
 * 🛡️ GATEKEEPER: Sync Permissions
 */

// 1. Listen for new permissions from OpenCode (SSE)
/**
 * 👂 listenForPermissions
 * Connects to the OpenCode Server-Sent Events (SSE) stream.
 * Listens for 'permission.asked' events and triggers the Gatekeeper flow.
 */
async function listenForPermissions() {
    console.log("🛡️ [Gatekeeper] Connecting to OpenCode Event Stream...");
    const evtSource = new EventSource(`${OPENCODE_URL}/event`);

    evtSource.onmessage = async (event) => {
        try {
            console.log("📥 [Gatekeeper] Event received:", event.data);
            const data = JSON.parse(event.data);

            if (data.type === 'permission.asked') {
                console.log("🛡️ [Gatekeeper] Permission Asked! Payload:", JSON.stringify(data));
                const payload = data.properties || data;
                await handlePermissionAsked(payload);
            }
        } catch (e) {
            console.error("❌ [Gatekeeper] Event error:", e.message);
        }
    };

    evtSource.onerror = (err) => {
        console.error("❌ [Gatekeeper] SSE Error. Reconnecting...", err);
        // EventSource auto-reconnects, but we log it.
    };
}

// 2. Handle 'permission.asked' -> Query the Sovereign Authority
/**
 * 🛡️ handlePermissionAsked
 * The entry point for the "Sovereign Authority" flow.
 * 1. Resolves the Chat ID from the OpenCode Session ID.
 * 2. POSTs the intent to the PocketBase /api/pocketcoder/permission endpoint.
 * 3. Acts on the decision (Auto-Authorize or Manual Gate).
 * 
 * @param {Object} payload - The permission request payload from OpenCode.
 */
async function handlePermissionAsked(payload) {
    const permId = payload.id;
    console.log(`🛡️ [Relay] Intent Received: ${permId} (${payload.permission})`);

    try {
        let chatId = sessionToChat.get(payload.sessionID);
        if (!chatId) {
            try {
                const chat = await pb.collection('chats').getFirstListItem(`opencode_id = "${payload.sessionID}"`);
                chatId = chat.id;
                sessionToChat.set(payload.sessionID, chatId);
            } catch (e) {
                console.warn(`⚠️ [Relay] No chat context for session ${payload.sessionID}`);
                chatId = currentChatId;
            }
        }

        // --- QUERY SOVEREIGN AUTHORITY ---
        const authRes = await fetch(`${POCKETBASE_URL}/api/pocketcoder/permission`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                permission: payload.permission,
                patterns: payload.patterns || [],
                chat_id: chatId,
                session_id: payload.sessionID,
                opencode_id: payload.id,
                metadata: payload.metadata || {},
                message: payload.message || "Requested via OpenCode",
                message_id: payload.tool?.messageID,
                call_id: payload.tool?.callID
            })
        });

        if (!authRes.ok) throw new Error(`Authority Error: ${authRes.status}`);

        const decision = await authRes.json();

        if (decision.permitted) {
            console.log(`✅ [Relay] Sovereign Authority: AUTO-AUTHORIZED ${permId}`);
            await replyToOpenCode(payload.id, 'once');
        } else {
            console.log(`⏳ [Relay] Sovereign Authority: GATED ${permId} (Status: ${decision.status})`);
            // The /permission endpoint created the 'draft' record. 
            // The PB subscription (subscribeToPermissionUpdates) will handle manual auth.
        }

    } catch (e) {
        console.error(`❌ [Relay] Permission handling failed:`, e.message);
    }
}

// 3. Listen for PocketBase 'authorized'/'denied' (Manual Auth) -> Reply to OpenCode
async function subscribeToPermissionUpdates() {
    console.log("📡 [Relay] Subscribing to permission updates...");
    pb.collection('permissions').subscribe('*', async (e) => {
        // We only care about UPDATES here (User moving from 'draft' -> 'authorized'/'denied')
        // Initial 'create' for auto-auth is handled synchronously in handlePermissionAsked.
        if (e.action === 'update') {
            const record = e.record;
            if (record.status === 'authorized') {
                await replyToOpenCode(record.opencode_id, 'once');
            } else if (record.status === 'denied') {
                await replyToOpenCode(record.opencode_id, 'reject');
            }
        }
    });
}

// 4. Send Reply to OpenCode
async function replyToOpenCode(requestID, replyType) {
    console.log(`🔓 [Gatekeeper] Replying to OpenCode: ${requestID} -> ${replyType}`);
    try {
        const res = await fetch(`${OPENCODE_URL}/permission/${requestID}/reply`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                reply: replyType,
                message: replyType === 'reject' ? "User denied permission." : undefined
            })
        });

        if (!res.ok) {
            console.error(`❌ [Gatekeeper] Reply failed: ${res.status}`);
        } else {
            console.log(`✅ [Gatekeeper] ${replyType.toUpperCase()} sent successfully.`);
        }
    } catch (e) {
        console.error(`❌ [Gatekeeper] Network error replying: ${e.message}`);
    }
}

/**
 * 🤖 AI REGISTRY: Deploy Agents
 */
async function subscribeToAgentUpdates() {
    console.log("📡 [Relay] Subscribing to AI Registry updates...");

    const deployAgent = async (agent) => {
        const { name, is_init, config } = agent;
        if (!name || !config) return;

        const fileName = `${name}.md`;
        // Target paths (relative to container or absolute if matched to host)
        const targetDir = is_init
            ? "/workspace/.opencode/agents"
            : "/workspace/sandbox/cao/agent_store";

        try {
            await fs.mkdir(targetDir, { recursive: true });
            const filePath = path.join(targetDir, fileName);
            await fs.writeFile(filePath, config);
            console.log(`🚀 [Relay] Deployed Agent: ${name} -> ${filePath}`);
        } catch (e) {
            console.error(`❌ [Relay] Failed to deploy agent ${name}:`, e.message);
        }
    };

    // 1. Initial Sync (Catch up)
    try {
        const agents = await pb.collection('ai_agents').getFullList();
        for (const agent of agents) {
            await deployAgent(agent);
        }
    } catch (e) {
        console.warn("⚠️ [Relay] Initial agent sync failed:", e.message);
    }

    // 2. Realtime Watch
    pb.collection('ai_agents').subscribe('*', async (e) => {
        if (e.action === 'create' || e.action === 'update') {
            await deployAgent(e.record);
        }
    });
}


/**
 * Get or create OpenCode session for a specific chat
 */
async function ensureOpencodeSession(chatId) {
    if (!chatId) return null;

    let agentName = 'poco'; // Default
    try {
        console.log(`🔍 [Chat Relay] ensureOpencodeSession: fetching chat ${chatId}`);
        const chat = await pb.collection('chats').getOne(chatId, {
            expand: 'agent'
        });
        agentName = chat.expand?.agent?.name || 'poco';
        console.log(`🔍 [Chat Relay] ensureOpencodeSession: chat found, opencode_id: ${chat.opencode_id}, agent: ${agentName}`);
        if (chat.opencode_id) {
            // Check if session is still alive
            try {
                const url = `${OPENCODE_URL}/session/${chat.opencode_id}`;
                console.log(`🔍 [Chat Relay] ensureOpencodeSession: checking session via ${url}`);
                const res = await fetch(url);
                console.log(`🔍 [Chat Relay] ensureOpencodeSession: check session status: ${res.status}`);
                if (res.ok) {
                    sessionToChat.set(chat.opencode_id, chatId);
                    return chat.opencode_id;
                }
            } catch (e) {
                console.warn(`⚠️ [Chat Relay] Session ${chat.opencode_id} invalid, creating new one... ${e.message}`);
            }
        }
    } catch (e) {
        console.error(`❌ [Chat Relay] Failed to fetch chat ${chatId}:`, e.message);
        // If chat fetch fails, we can't safely proceed
        return null;
    }

    let retryCount = 0;
    const maxRetries = 15;

    while (retryCount < maxRetries) {
        try {
            console.log(`🔍 [Chat Relay] ensureOpencodeSession: creating new session (Attempt ${retryCount + 1})`);
            const res = await fetch(`${OPENCODE_URL}/session`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    directory: "/workspace",
                    agent: agentName
                }),
            });

            console.log(`🔍 [Chat Relay] ensureOpencodeSession: create session status: ${res.status}`);
            if (!res.ok) {
                const text = await res.text();
                throw new Error(`OpenCode session creation failed: ${res.status} - ${text.slice(0, 100)}`);
            }

            const data = await res.json();
            const sessionId = data.id;
            console.log(`🔍 [Chat Relay] ensureOpencodeSession: session created: ${sessionId}, linking to chat...`);

            // Link this chat to the new session
            await pb.collection('chats').update(chatId, {
                opencode_id: sessionId
            });

            sessionToChat.set(sessionId, chatId);
            console.log(`✅ [Chat Relay] Linked chat ${chatId} to OpenCode session: ${sessionId}`);
            return sessionId;
        } catch (e) {
            retryCount++;
            console.warn(`⚠️ [Chat Relay] Failed to connect to OpenCode (Attempt ${retryCount}/${maxRetries}):`, e.message);
            if (retryCount < maxRetries) await new Promise(r => setTimeout(r, 2000));
        }
    }

    console.error("❌ [Chat Relay] Could not establish OpenCode session after multiple attempts.");
    return null;
}

/**
 * Handle a new user message
 */
async function processUserMessage(msg) {
    // Skip if not a user message or already processed
    if (msg.role !== 'user' || msg.metadata?.processed === true) return;

    console.log(`📨 [Chat Relay] Processing message: ${msg.id}`);
    if (msg.chat) {
        currentChatId = msg.chat;
        console.log(`📍 [Chat Relay] Current chat context set to: ${currentChatId}`);
    } else {
        console.warn(`⚠️ [Chat Relay] Message ${msg.id} has no chat association!`);
    }

    // Mark as processed immediately to prevent double-processing
    try {
        await pb.collection('messages').update(msg.id, {
            metadata: { ...msg.metadata, processed: true }
        });
    } catch (e) {
        console.error(`❌ [Chat Relay] Failed to mark message ${msg.id} as processed:`, e.message);
        return;
    }

    const sessionId = await ensureOpencodeSession(msg.chat);
    if (!sessionId) {
        console.error("❌ [Chat Relay] No OpenCode session, skipping message");
        return;
    }

    // Extract text content
    const textParts = (msg.parts || [])
        .filter(p => p.type === 'text')
        .map(p => p.content || p.text)
        .join('\n');

    if (!textParts) {
        console.warn(`⚠️ [Chat Relay] Message ${msg.id} has no text parts, skipping`);
        return;
    }

    try {
        // Send to OpenCode
        const res = await fetch(`${OPENCODE_URL}/session/${sessionId}/message`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                parts: [{ type: 'text', text: textParts }]
            }),
        });

        if (!res.ok) {
            const errText = await res.text();
            throw new Error(`Prompt failed: ${res.status} - ${errText.slice(0, 100)}`);
        }

        const promptData = await res.json();
        console.log("📥 [Chat Relay] OpenCode Prompt Response:", JSON.stringify(promptData));
        // ID is in info.id for the initial response!
        const opencodeMsgId = promptData.id || promptData.info?.id;

        console.log(`✅ [Chat Relay] Prompt sent, OpenCode message ID: ${opencodeMsgId}`);

        if (!opencodeMsgId) {
            console.error("❌ [Chat Relay] Could not extract message ID from response:", JSON.stringify(promptData));
            return;
        }

        // Check if already completed (synchronous response)
        if (promptData.info?.time?.completed || promptData.finish) {
            console.log(`⚡ [Chat Relay] Response completed immediately.`);
            await saveAssistantResponse(msg.chat, promptData);
            return;
        }

        // Poll OpenCode for response (Future: Use OpenCode SSE if available)
        await pollOpenCodeResponse(sessionId, opencodeMsgId, msg.chat);

    } catch (e) {
        console.error("❌ [Chat Relay] OpenCode error:", e.message);
    }
}

/**
 * Poll OpenCode for response and sync back to PocketBase
 */
async function pollOpenCodeResponse(sessionId, opencodeMsgId, pbChatId) {
    let attempts = 0;
    const maxAttempts = 120; // 2 minutes max
    let lastStatus = null;

    while (attempts < maxAttempts) {
        try {
            const res = await fetch(`${OPENCODE_URL}/session/${sessionId}/message/${opencodeMsgId}`);
            if (!res.ok) {
                await new Promise(r => setTimeout(r, 1000));
                attempts++;
                continue;
            }

            const message = await res.json();
            const isCompleted = !!message.info?.time?.completed;

            if (isCompleted !== lastStatus) {
                console.log(`🔄 [Chat Relay] OpenCode message complete: ${isCompleted}`);
                lastStatus = isCompleted;
            }

            // Sync parts to PocketBase periodically or on finish
            // This allows the UI to see "tool use" parts before the message is complete!
            if (message.parts && message.parts.length > 0) {
                await saveAssistantResponse(pbChatId, message);

                // If done, we stop polling
                if (isCompleted) {
                    console.log(`✅ [Chat Relay] Response finalized for chat ${pbChatId}`);
                    return;
                }
            }

            await new Promise(r => setTimeout(r, 1000));
            attempts++;
        } catch (e) {
            console.error("❌ [Chat Relay] Polling error:", e.message);
            await new Promise(r => setTimeout(r, 2000));
            attempts++;
        }
    }
    console.warn("⚠️ [Chat Relay] Response timeout");
}

/**
 * Save assistant message to PocketBase
 */
async function saveAssistantResponse(chatId, opencodeMessage) {
    try {
        const msgId = opencodeMessage.id || opencodeMessage.info?.id;

        if (!opencodeMessage.parts || opencodeMessage.parts.length === 0) {
            console.log(`🔍 [Chat Relay] saveAssistantResponse: no parts for message ${msgId}, skipping sync`);
            return;
        }

        if (!msgId) {
            console.error("❌ [Chat Relay] Cannot save assistant response: missing message ID", JSON.stringify(opencodeMessage).slice(0, 200));
            return;
        }

        // Pass parts through to PocketBase. Dart client handles the schema matching.
        const parts = opencodeMessage.parts.map(p => {
            if (p.type === 'text' && !p.text && p.content) {
                return { ...p, text: p.content };
            }
            return p;
        });

        // Check if message already exists (upsert logic)
        try {
            const existing = await pb.collection('messages').getFirstListItem(`metadata.opencodeId = "${msgId}"`);

            // Update
            await pb.collection('messages').update(existing.id, {
                parts: parts
            });
        } catch (e) {
            // Create New
            if (e.status === 404) {
                await pb.collection('messages').create({
                    chat: chatId,
                    role: 'assistant',
                    parts: parts,
                    metadata: { opencodeId: msgId }
                });
                console.log(`💾 [Chat Relay] Created response for ${msgId}`);
            } else {
                throw e;
            }
        }

    } catch (e) {
        console.error("❌ [Chat Relay] Failed to save/update assistant response:", e.message);
    }
}

/**
 * Main Loop
 */
async function start() {
    try {
        // 1. Authenticate
        console.log(`🔑 [Chat Relay] Attempting login as ${AGENT_EMAIL}...`);
        await pb.collection('users').authWithPassword(AGENT_EMAIL, AGENT_PASSWORD);
        console.log("✅ [Chat Relay] Logged in to PocketBase");
        console.log("   Auth ID:", pb.authStore.model.id);
        console.log("   Auth Role:", pb.authStore.model.role);

        // 2. Start Gatekeeper (Permissions)
        await listenForPermissions();
        await subscribeToPermissionUpdates();

        // 3. Subscribe to Chat Messages
        console.log("📡 [Chat Relay] Subscribing to messages...");
        pb.collection('messages').subscribe('*', (e) => {
            console.log(`🔔 [Chat Relay] Received message event: ${e.action} for ${e.record.id}`);
            if (e.action === 'create') {
                processUserMessage(e.record);
            }
        });

        // 4. Subscribe to Agent Registry (Deployment)
        await subscribeToAgentUpdates();

    } catch (e) {
        console.error("❌ [Chat Relay] Critical Error:", e);
        if (e.response) console.error("   Response:", e.response);
        setTimeout(start, 5000); // Retry after 5s
    }
}

// Global error handling
process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

start();
