/**
 * 🏰 POCKETCODER SOVEREIGN PLUGIN
 * This plugin hooks into OpenCode's internal permission system and
 * synchronizes all intents with PocketBase.
 */

export default function pocketcoderPlugin() {
    console.log("🏰 [PocketCoder] Intent Plugin Initialized");
    const POCKETBASE_URL = process.env.POCKETBASE_URL || 'http://pocketbase:8090';
    const AGENT_EMAIL = process.env.AGENT_EMAIL || 'agent@pocketcoder.local';
    const AGENT_PASS = process.env.AGENT_PASSWORD;

    const intentMap = new Map<string, string>();
    let token: string | null = null;

    async function getAuthToken() {
        if (token) return token;
        if (!AGENT_PASS) {
            throw new Error("[PocketCoder] AGENT_PASSWORD environment variable is not set. Intent Gate cannot be established.");
        }
        const res = await fetch(`${POCKETBASE_URL}/api/collections/users/auth-with-password`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ identity: AGENT_EMAIL, password: AGENT_PASS }),
        });
        const data = await res.json() as any;
        token = data.token;
        if (!token) throw new Error("Authentication failed: " + JSON.stringify(data));
        return token;
    }

    return {
        name: "pocketcoder-plugin",
        hooks: {
            "permission.ask": async (info: any, output: any) => {
                console.log(`[PocketCoder] Intercepting Permission Request: ${info.message}`);

                try {
                    const authToken = await getAuthToken();

                    // 1. Create the Intent in the PocketBase (1:1 with OpenCode Info)
                    const intentRes = await fetch(`${POCKETBASE_URL}/api/collections/intents/records`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'Authorization': `Bearer ${authToken}`
                        },
                        body: JSON.stringify({
                            opencode_id: info.id,
                            type: info.type,
                            message: info.message,
                            metadata: info.metadata,
                            pattern: info.pattern,
                            session_id: info.sessionID,
                            message_id: info.messageID,
                            call_id: info.callID,
                            time_created: info.time?.created || Date.now(),
                            status: "draft",
                            reasoning: "Awaiting user authorization via Gatekeeper."
                        }),
                    });

                    if (!intentRes.ok) {
                        const errText = await intentRes.text();
                        throw new Error(`Failed to create intent: ${intentRes.statusText} - ${errText}`);
                    }
                    const intent = await intentRes.json() as any;

                    console.log(`[PocketCoder] Intent created: ${intent.id}. Waiting for signature...`);

                    // 2. Poll for signature (wait up to 5 minutes)
                    const start = Date.now();
                    while (Date.now() - start < 300000) {
                        const checkRes = await fetch(`${POCKETBASE_URL}/api/collections/intents/records/${intent.id}`, {
                            headers: { 'Authorization': `Bearer ${authToken}` }
                        });
                        const check = await checkRes.json() as any;

                        if (check.status === 'authorized') {
                            console.log(`[PocketCoder] Authorized! ${intent.id}`);

                            // 🔑 Save the receipt for the execution hook
                            if (info.callID) {
                                intentMap.set(info.callID, intent.id);
                            }

                            output.status = "allow";
                            return;
                        }
                        if (check.status === 'denied') {
                            console.log(`[PocketCoder] Denied! ${intent.id}`);
                            output.status = "deny";
                            return;
                        }

                        await new Promise(r => setTimeout(r, 2000));
                    }

                    console.log(`[PocketCoder] Timeout waiting for signature for ${intent.id}`);
                    output.status = "deny";

                } catch (err) {
                    console.error(`[PocketCoder] Error in Gatekeeper:`, err);
                    output.status = "deny"; // Default to safety
                }
            },
            "tool.execute.before": async (input: any, output: any) => {
                const intentId = intentMap.get(input.callID);
                if (intentId) {
                    console.log(`[PocketCoder] Injecting Receipt for Call: ${input.callID} -> Intent: ${intentId}`);
                    output.args = {
                        ...output.args,
                        intent_id: intentId
                    };
                    intentMap.delete(input.callID); // One-time use receipts
                }
            }
        }
    };
}
