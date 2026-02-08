#!/usr/bin/env node
/**
 * 🌉 POCKETCODER CHAT BRIDGE (SDK VERSION)
 * 
 * This service bridges PocketBase and OpenCode using the PocketBase JS SDK:
 * 1. Subscribes to new user messages in PocketBase (Realtime)
 * 2. Catches up on missed messages on startup (Recovery)
 * 3. Sends them to OpenCode via REST API
 * 4. Streams responses back to PocketBase for the UI
 */

import PocketBase from 'pocketbase';
import { EventSource } from 'eventsource';

// Required for PocketBase Realtime in Node.js
global.EventSource = EventSource;

const POCKETBASE_URL = process.env.POCKETBASE_URL || "http://pocketbase:8090";
const OPENCODE_URL = process.env.OPENCODE_URL || "http://opencode:3000";
const AGENT_EMAIL = process.env.AGENT_EMAIL || 'agent@pocketcoder.local';
const AGENT_PASSWORD = process.env.AGENT_PASSWORD || 'EJ6IiRKdHR8Do6IogD7PApyErxDZhUmp';

const pb = new PocketBase(POCKETBASE_URL);
let opencodeSessionId = null;

console.log("🌉 [Chat Bridge] Starting Realtime Bridge...");
console.log(`   PocketBase: ${POCKETBASE_URL}`);
console.log(`   OpenCode: ${OPENCODE_URL}`);

/**
 * Get or create OpenCode session
 */
async function ensureOpencodeSession() {
    if (opencodeSessionId) {
        try {
            const res = await fetch(`${OPENCODE_URL}/session/${opencodeSessionId}`);
            if (res.ok) return opencodeSessionId;
        } catch (e) {
            console.warn("⚠️ [Chat Bridge] Cached OpenCode session invalid");
        }
    }

    let retryCount = 0;
    const maxRetries = 15;

    while (retryCount < maxRetries) {
        try {
            const res = await fetch(`${OPENCODE_URL}/session`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ directory: "/workspace" }),
            });

            if (!res.ok) {
                const text = await res.text();
                throw new Error(`OpenCode session creation failed: ${res.status} - ${text.slice(0, 100)}`);
            }

            const text = await res.text();
            let data;
            try {
                data = JSON.parse(text);
            } catch (e) {
                console.error(`❌ [Chat Bridge] Response from ${OPENCODE_URL}/session was not JSON:`, text);
                throw new Error(`OpenCode response was not JSON`);
            }

            opencodeSessionId = data.id;
            console.log(`✅ [Chat Bridge] OpenCode session: ${opencodeSessionId}`);
            return opencodeSessionId;
        } catch (e) {
            retryCount++;
            console.warn(`⚠️ [Chat Bridge] Failed to connect to OpenCode (Attempt ${retryCount}/${maxRetries}):`, e.message);
            if (retryCount < maxRetries) await new Promise(r => setTimeout(r, 2000));
        }
    }

    console.error("❌ [Chat Bridge] Could not establish OpenCode session after multiple attempts.");
    return null;
}

/**
 * Handle a new user message
 */
async function processUserMessage(msg) {
    // Skip if not a user message or already processed
    if (msg.role !== 'user' || msg.metadata?.processed === true) return;

    console.log(`📨 [Chat Bridge] Processing message: ${msg.id}`);

    // Mark as processed immediately to prevent double-processing
    try {
        await pb.collection('messages').update(msg.id, {
            metadata: { ...msg.metadata, processed: true }
        });
    } catch (e) {
        console.error(`❌ [Chat Bridge] Failed to mark message ${msg.id} as processed:`, e.message);
        return;
    }

    const sessionId = await ensureOpencodeSession();
    if (!sessionId) {
        console.error("❌ [Chat Bridge] No OpenCode session, skipping message");
        return;
    }

    // Extract text content
    const textParts = (msg.parts || [])
        .filter(p => p.type === 'text')
        .map(p => p.content || p.text)
        .join('\n');

    if (!textParts) {
        console.warn(`⚠️ [Chat Bridge] Message ${msg.id} has no text parts, skipping`);
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
        // ID is in info.id for the initial response!
        const opencodeMsgId = promptData.id || promptData.info?.id;

        console.log(`✅ [Chat Bridge] Prompt sent, OpenCode message ID: ${opencodeMsgId}`);

        if (!opencodeMsgId) {
            console.error("❌ [Chat Bridge] Could not extract message ID from response:", JSON.stringify(promptData));
            return;
        }

        // Check if already completed (synchronous response)
        if (promptData.info?.time?.completed || promptData.finish) {
            console.log(`⚡ [Chat Bridge] Response completed immediately.`);
            await saveAssistantResponse(msg.chat, promptData);
            return;
        }

        // Poll OpenCode for response (Future: Use OpenCode SSE if available)
        await pollOpenCodeResponse(sessionId, opencodeMsgId, msg.chat);

    } catch (e) {
        console.error("❌ [Chat Bridge] OpenCode error:", e.message);
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
                console.log(`🔄 [Chat Bridge] OpenCode message complete: ${isCompleted}`);
                lastStatus = isCompleted;
            }

            // Sync parts to PocketBase periodically or on finish
            if (message.parts && message.parts.length > 0) {
                // If done, save the final version
                if (isCompleted) {
                    await saveAssistantResponse(pbChatId, message);
                    console.log(`✅ [Chat Bridge] Response finalized for chat ${pbChatId}`);
                    return;
                }
            }

            await new Promise(r => setTimeout(r, 1000));
            attempts++;
        } catch (e) {
            console.error("❌ [Chat Bridge] Polling error:", e.message);
            await new Promise(r => setTimeout(r, 2000));
            attempts++;
        }
    }
    console.warn("⚠️ [Chat Bridge] Response timeout");
}

/**
 * Save assistant message to PocketBase
 */
async function saveAssistantResponse(chatId, opencodeMessage) {
    try {
        console.log(`💾 [Chat Bridge] Saving response with parts:`, JSON.stringify(opencodeMessage.parts, null, 2));

        if (!opencodeMessage.parts || opencodeMessage.parts.length === 0) {
            console.warn("⚠️ [Chat Bridge] No parts to save");
            return;
        }

        // Pass parts through to PocketBase. Dart client handles the schema matching.
        // We only ensure 'text' is set for text parts if it's missing (legacy support).
        const parts = opencodeMessage.parts.map(p => {
            if (p.type === 'text' && !p.text && p.content) {
                return { ...p, text: p.content };
            }
            return p;
        });

        await pb.collection('messages').create({
            chat: chatId,
            role: 'assistant',
            parts: parts,
            metadata: { opencodeId: opencodeMessage.id }
        });
    } catch (e) {
        console.error("❌ [Chat Bridge] Failed to save assistant response:", e.message);
    }
}

/**
 * Main Loop
 */
async function start() {
    try {
        // 1. Authenticate
        await pb.collection('users').authWithPassword(AGENT_EMAIL, AGENT_PASSWORD);
        console.log("✅ [Chat Bridge] Logged in to PocketBase");

        // 3. Subscribe to Realtime
        console.log("📡 [Chat Bridge] Subscribing to messages...");
        pb.collection('messages').subscribe('*', (e) => {
            if (e.action === 'create') {
                processUserMessage(e.record);
            }
        });

    } catch (e) {
        console.error("❌ [Chat Bridge] Critical Error:", e);
        if (e.response) console.error("   Response:", e.response);
        setTimeout(start, 5000); // Retry after 5s
    }
}

// Global error handling
process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

start();
