/**
 * 📡 POCKETCODER COMMUNICATIONS OFFICER (CHAT & LOGS)
 * 
 * Role:
 * 1. Hot Pipe: Stream real-time events to the UI (Matrix effect).
 * 2. Cold Pipe: Persist logs to disk for auditability.
 * 3. Chat Sync: (Future) Poll/Push messages between DB and OpenCode.
 */

import * as fs from 'fs';
import * as path from 'path';

export default async ({ client }: any) => {
    console.log("📡 [PocketCoder] Communications Officer On Deck");

    const POCKETBASE_URL = process.env.POCKETBASE_URL || "http://pocketbase:8090";
    const AGENT_EMAIL = process.env.AGENT_EMAIL || 'agent@pocketcoder.local';
    const AGENT_PASSWORD = process.env.AGENT_PASSWORD || 'EJ6IiRKdHR8Do6IogD7PApyErxDZhUmp';
    const LOG_DIR = "/logs";

    let token: string | null = null;
    let jobID = "default"; // TODO: Get from session ID or environment

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
            const data = await res.json() as any;
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
    function logToFile(text: string) {
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
    async function streamToUI(topic: string, data: any) {
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

    return {
        name: "chat-plugin",
        "event": async ({ event }: any) => {
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

                    // Cold Pipe (maybe too verbose? logging chunks is messy. Log full message on finish instead?)
                    // For now, let's log major events to cold pipe.
                }
            }

            // 2. CAPTURE COMPLETE STEPS/MESSAGES
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
