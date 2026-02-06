/**
 * 📡 POCKETCODER COMMUNICATIONS OFFICER (CHAT & LOGS)
 * 
 * Role:
 * 1. Hot Pipe: Stream real-time events to the UI (Matrix effect).
 * 2. Cold Pipe: Persist logs to disk for auditability.
 * 3. Chat Sync: (Future) Poll/Push messages between DB and OpenCode.
 */

import fs from 'fs';
console.log("📡 [PocketCoder] [DEBUG] chat-plugin.mjs EVALUATING...");
import path from 'path';

export default async ({ client }) => {
    console.log("📡 [PocketCoder] [DEBUG] chat-plugin.mjs starting...");
    try { fs.writeFileSync('/logs/plugin_startup.txt', 'Plugin Loaded at ' + new Date().toISOString()); } catch (e) { }

    const POCKETBASE_URL = process.env.POCKETBASE_URL || "http://pocketbase:8090";
    const AGENT_EMAIL = process.env.AGENT_EMAIL || 'agent@pocketcoder.local';
    const AGENT_PASSWORD = process.env.AGENT_PASSWORD || 'EJ6IiRKdHR8Do6IogD7PApyErxDZhUmp';
    const LOG_DIR = "/logs";

    let token = null;
    let jobID = null; // Will be discovered or created dynamically

    // Ensure log directory exists (should be mounted, but safe check)
    if (!fs.existsSync(LOG_DIR)) {
        try {
            fs.mkdirSync(LOG_DIR, { recursive: true });
        } catch (e) {
            console.error("📡 [PocketCoder] Failed to create log dir:", e);
        }
    }

    async function getAuthToken() {
        if (token) return token;
        try {
            const res = await fetch(`${POCKETBASE_URL}/api/collections/users/auth-with-password`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ identity: AGENT_EMAIL, password: AGENT_PASSWORD }),
            });
            if (!res.ok) throw new Error("Auth Failed");
            const data = await res.json();
            token = data.token;
            return token;
        } catch (e) {
            console.error("📡 [PocketCoder] Auth Error:", e);
            return null;
        }
    }

    /**
     * 🧊 COLD PIPE: File Logging
     */
    function logToFile(text) {
        try {
            const logFile = path.join(LOG_DIR, `job_${jobID}.log`);
            const timestamp = new Date().toISOString();
            fs.appendFileSync(logFile, `[${timestamp}] ${text}\n`);
        } catch (e) {
            console.error("📡 [PocketCoder] Cold Pipe Error:", e);
        }
    }

    /**
     * 🔥 HOT PIPE: Ephemeral Stream
     */
    async function streamToUI(topic, data) {
        const authToken = await getAuthToken();
        if (!authToken) return;

        try {
            // Fire and forget (don't await to avoid blocking)
            fetch(`${POCKETBASE_URL}/api/pocketcoder/stream`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${authToken}`
                },
                body: JSON.stringify({
                    topic: topic,
                    data: data
                })
            }).catch(e => console.error("📡 [PocketCoder] Hot Pipe Transport Error:", e));
        } catch (e) {
            console.error("📡 [PocketCoder] Hot Pipe Error:", e);
        }
    }

    /**
     * 📥 INBOUND PIPE: Poll for User Messages
     */
    // Start from a few hours ago to pick up missed messages on restart
    let lastCheck = new Date(Date.now() - 4 * 60 * 60 * 1000).toISOString();

    /**
     * 📥 INBOUND PIPE: Poll for User Messages
     */
    async function pollInbox() {
        console.log("📡 [PocketCoder] [DEBUG] pollInbox check...");
        const authToken = await getAuthToken();
        if (!authToken) {
            console.log("📡 [PocketCoder] [DEBUG] pollInbox: No authToken, retrying...");
            setTimeout(pollInbox, 2000);
            return;
        }

        try {
            // Fetch NEW messages (user role, not processed)
            // Note: PocketBase filter syntax for JSON fields is tricky. 
            // Simpler: Fetch user messages created > last check, then check metadata client-side if needed 
            // OR use a dedicated 'read' field if we had one.
            // Let's stick to created > lastCheck for the "Tail" behavior, 
            // BUT we also need to ensure we don't re-process if we crash/restart.
            // For this prototype, 'created' > 'now' (at startup) + memory cursor is safest to prevent replay loops on restart.

            // Fetch messages for this chat (filtering by processed in JS for now if needed, 
            // but for simplicity we fetch and check metadata.processed)
            const filter = `role = 'user'`;
            const url = `${POCKETBASE_URL}/api/collections/messages/records?filter=${encodeURIComponent(filter)}`;

            // console.log(`📡 [PocketCoder] [DEBUG] polling: ${url}`);
            const res = await fetch(url, {
                headers: { 'Authorization': `Bearer ${authToken}` }
            });

            if (res.ok) {
                const data = await res.json();
                console.log(`📡 [PocketCoder] [DEBUG] pollInbox: Found ${data.items ? data.items.length : 0} items`);
                if (data.items && data.items.length > 0) {
                    for (const msg of data.items) {
                        lastCheck = msg.created;

                        // Skip if already processed (double safety)
                        if (msg.metadata?.processed) continue;

                        console.log(`📨 [PocketCoder] INBOUND MESSAGE: ${msg.id}`);

                        // 🔍 Dynamic Session Discovery & Recovery
                        let activeSessionID = jobID;

                        try {
                            if (!activeSessionID) {
                                // 1. Try to find any existing session
                                const sessions = await client.session.list();
                                if (sessions && sessions.length > 0) {
                                    activeSessionID = sessions[0].id;
                                    jobID = activeSessionID;
                                    console.log(`📡 [PocketCoder] [DEBUG] Discovered existing session: ${activeSessionID}`);
                                } else {
                                    // 2. Create a new session if none exist
                                    console.log("📡 [PocketCoder] [DEBUG] Creating fresh session...");
                                    const newSessionRes = await client.session.create({
                                        body: { directory: "/workspace" }
                                    });

                                    // Handle different return formats from SDK
                                    activeSessionID = newSessionRes.id || (newSessionRes.data ? newSessionRes.data.id : null);

                                    if (!activeSessionID) {
                                        // Fallback: list again to find it
                                        const retryList = await client.session.list();
                                        activeSessionID = retryList[0]?.id;
                                    }

                                    jobID = activeSessionID;
                                    console.log(`📡 [PocketCoder] [DEBUG] New session created: ${activeSessionID}`);
                                }
                            } else {
                                // 3. Verify the cached session still exists
                                try {
                                    await client.session.get({ path: { id: activeSessionID } });
                                } catch (e) {
                                    console.warn(`📡 [PocketCoder] [DEBUG] Cached session ${activeSessionID} is gone, rediscovering...`);
                                    jobID = null;
                                    activeSessionID = null;
                                    // Recursive call next poll will fix it
                                    // We don't throw here, just let activeSessionID be null for this message
                                }
                            }
                        } catch (err) {
                            console.error("📡 [PocketCoder] [DEBUG] Session Discovery Failed:", err);
                        }

                        // Extract Text Parts
                        const textParts = (msg.parts || [])
                            .filter(p => p.type === 'text')
                            .map(p => ({ type: 'text', text: p.content }));

                        if (textParts.length > 0 && activeSessionID) {
                            try {
                                console.log(`🧠 [PocketCoder] Injecting into Brain (Session: ${activeSessionID})`);
                                await client.session.prompt({
                                    path: { id: activeSessionID },
                                    body: {
                                        parts: textParts
                                    }
                                });

                                // Mark as processed
                                console.log(`📨 [PocketCoder] Marking as processed: ${msg.id}`);
                                await fetch(`${POCKETBASE_URL}/api/collections/messages/records/${msg.id}`, {
                                    method: 'PATCH',
                                    headers: {
                                        'Authorization': `Bearer ${authToken}`,
                                        'Content-Type': 'application/json'
                                    },
                                    body: JSON.stringify({
                                        metadata: { ...msg.metadata, processed: true }
                                    })
                                });
                                console.log(`📨 [PocketCoder] Marked processed: ${msg.id}`);

                            } catch (err) {
                                console.error("🧠 [PocketCoder] Injection Failed:", err);
                                // IMPORTANT: Mark as processed even on failure to prevent loops
                                await fetch(`${POCKETBASE_URL}/api/collections/messages/records/${msg.id}`, {
                                    method: 'PATCH',
                                    headers: {
                                        'Authorization': `Bearer ${authToken}`,
                                        'Content-Type': 'application/json'
                                    },
                                    body: JSON.stringify({
                                        metadata: { ...msg.metadata, processed: true, error: err.message }
                                    })
                                });
                            }
                        } else {
                            // If we couldn't get a session, we MUST still mark as processed (or fail) to stop the loop
                            console.warn(`📡 [PocketCoder] [DEBUG] Skipping injection for ${msg.id} (No active session)`);
                            await fetch(`${POCKETBASE_URL}/api/collections/messages/records/${msg.id}`, {
                                method: 'PATCH',
                                headers: {
                                    'Authorization': `Bearer ${authToken}`,
                                    'Content-Type': 'application/json'
                                },
                                body: JSON.stringify({
                                    metadata: { ...msg.metadata, processed: true, error: "No active session" }
                                })
                            });
                        }
                    }
                }
            } else {
                console.error(`📡 [PocketCoder] [DEBUG] pollInbox failed with status ${res.status}`);
            }
        } catch (e) {
            console.error("📡 [PocketCoder] Inbound Poll Error:", e);
        }

        setTimeout(pollInbox, 1000);
    }

    // Start Polling
    pollInbox();

    return {
        name: "chat-plugin",
        "event": async ({ event }) => {
            // console.log(`📡 [PocketCoder] [DEBUG] EVENT: ${event.type}`);

            // Update Job ID if session changes
            if (event.properties?.info?.sessionID) {
                jobID = event.properties.info.sessionID;
            }

            // 1. CAPTURE MESSAGE DELTAS (The Matrix Effect)
            if (event.type === "message.part.updated") {
                const part = event.properties.part;

                // Only stream text deltas or tool updates
                if (part.content || (part.type === 'tool' && part.tool)) {
                    const payload = {
                        type: "delta",
                        content: part.content,
                        tool: part.tool,
                        callID: part.callID
                    };

                    // Hot Pipe
                    streamToUI("logs", payload);
                }
            }

            // 2. CAPTURE COMPLETE STEPS/MESSAGES
            if (event.type === "step-finish") {
                streamToUI("logs", { type: "finish" });
            }

            if (event.type === "step-finish" || event.type === "message.updated") {
                // Log to file
                const info = event.properties?.info || event.properties;
                logToFile(JSON.stringify(info));
            }

            // 3. CAPTURE PERMISSIONS (Audit)
            if (event.type === "permission.asked") {
                const info = event.properties.info;
                const logEntry = `PERMISSION ASKED: ${info.permission.type} for ${info.permission.identifier || 'unknown'}`;
                logToFile(logEntry);
                streamToUI("logs", { type: "system", text: logEntry });
            }
        }
    };
};
