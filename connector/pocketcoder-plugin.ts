/**
 * 🏰 POCKETCODER SOVEREIGN PLUGIN (GATEKEEPER)
 * 
 * This plugin is a PURE INTERCEPTOR. 
 * Every permission request is sent to PocketBase. 
 * PocketBase is the SOVEREIGN AUTHORITY on whether to allow or draft.
 */

export default async ({ client }: any) => {
    console.log("🏰 [PocketCoder] Sovereign Gatekeeper Active (Auth: PocketBase)");

    const POCKETBASE_URL = "http://pocketbase:8090";
    const AGENT_EMAIL = (typeof process !== 'undefined' ? process.env.AGENT_EMAIL : 'agent@pocketcoder.local');
    const AGENT_PASS = (typeof process !== 'undefined' ? process.env.AGENT_PASSWORD : 'EJ6IiRKdHR8Do6IogD7PApyErxDZhUmp');

    let token: string | null = null;
    const handled = new Set<string>();

    async function getAuthToken() {
        if (token) return token;
        try {
            const res = await fetch(`${POCKETBASE_URL}/api/collections/users/auth-with-password`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ identity: AGENT_EMAIL, password: AGENT_PASS }),
            });
            if (!res.ok) throw new Error("PocketBase Auth Failed");
            const data = await res.json() as any;
            token = data.token;
            return token;
        } catch (e) {
            console.error("🏰 [PocketCoder] Auth Error:", e);
            return null;
        }
    }

    /**
     * 📊 USAGE TRACKING (THE SOVEREIGN LEDGER)
     * Handles the creation and update of usage records for cost/token tracking.
     */
    async function getOrCreateUsage(messageID: string, callID: string) {
        console.log(`🏰 [PocketCoder] [DEBUG] getOrCreateUsage: messageID=${messageID} callID=${callID}`);
        const authToken = await getAuthToken();
        if (!authToken) return null;

        // 1. Check for existing usage for this specific call (idempotency)
        const checkRes = await fetch(`${POCKETBASE_URL}/api/collections/usages/records?filter=(message_id='${messageID}'%26%26part_id='${callID}')`, {
            headers: { 'Authorization': `Bearer ${authToken}` }
        });
        const checkData = await checkRes.json() as any;
        if (checkData.items?.length > 0) return checkData.items[0];

        // 2. Create a new "in-progress" record
        const createRes = await fetch(`${POCKETBASE_URL}/api/collections/usages/records`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${authToken}` },
            body: JSON.stringify({
                message_id: messageID,
                part_id: callID, // Using callID as the temporary part link
                status: "in-progress"
            }),
        });
        if (!createRes.ok) return null;
        return await createRes.json();
    }

    async function handlePermission(info: any, isHook: boolean, output?: any) {
        console.log(`🏰 [PocketCoder] [DEBUG] handlePermission: ${JSON.stringify(info)}`);

        const messageID = info.tool?.messageID || info.messageID;
        const callID = info.tool?.callID || info.callID;

        const authToken = await getAuthToken();
        if (!authToken) return "draft";

        // 1. Ensure a usage record exists for this turn
        if (messageID && callID) {
            const usage = await getOrCreateUsage(messageID, callID);
            if (usage && typeof process !== 'undefined') {
                process.env.POCKETCODER_USAGE_ID = usage.id;
                console.log(`🏰 [PocketCoder] [DEBUG] Linked TURN: ${usage.id}`);
            }
        }

        // Create or get permission record in PocketBase
        try {
            const data = {
                "opencode_id": info.id,
                "session_id": info.sessionID,
                "permission": info.permission,
                "patterns": info.patterns,
                "metadata": info.metadata,
                "always": info.always,
                "message_id": messageID,
                "call_id": callID,
                "status": "draft",
                "source": "opencode-plugin",
                "message": info.message
            };

            const response = await fetch(`${POCKETBASE_URL}/api/collections/permissions/records`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${authToken}`
                },
                body: JSON.stringify(data)
            });

            const result = await response.json();
            if (!response.ok) {
                if (result.code === 400 && result.data?.opencode_id?.code === "validation_not_unique") {
                    // Already exists, fetch it
                    const existingRes = await fetch(`${POCKETBASE_URL}/api/collections/permissions/records?filter=(opencode_id='${info.id}')`, {
                        headers: { 'Authorization': `Bearer ${authToken}` }
                    });
                    const existingData = await existingRes.json();
                    if (existingData.items?.[0]) {
                        return existingData.items[0].status;
                    }
                }
                console.error(`🏰 [PocketCoder] [DEBUG] Failed to handle permission: ${JSON.stringify(result)}`);
                return "draft";
            }

            // Return the status (it might have been changed by a server-side hook)
            return result.status || "draft";
        } catch (e) {
            console.error(`🏰 [PocketCoder] [DEBUG] Error in handlePermission: ${e}`);
            return "draft";
        }
    }

    /**
     * 🔄 TOKEN SYNC
     * Listens for the end of a step and syncs final token counts to the usage record.
     */
    async function syncUsage(part: any) {
        if (part.type !== "step-finish") return;

        const authToken = await getAuthToken();
        if (!authToken) return;

        console.log(`🏰 [PocketCoder] 🔄 SYNCING USAGE: Message ${part.messageID}, Tokens: ${JSON.stringify(part.tokens)}`);

        // Find the record for this message (correlated by message_id and part_id)
        // Wait, OpenCode part IDs are random. We correlate by message_id and the fact it's "in-progress"
        // Since steps are sequential, we take the OLDEST "in-progress" usage for this message.
        const searchRes = await fetch(`${POCKETBASE_URL}/api/collections/usages/records?filter=(message_id='${part.messageID}'%26%26status='in-progress')&sort=created`, {
            headers: { 'Authorization': `Bearer ${authToken}` }
        });
        const searchData = await searchRes.json() as any;
        const usage = searchData.items?.[0];

        if (!usage) {
            console.warn(`🏰 [PocketCoder] ⚠️ No in-progress usage record found for message ${part.messageID}`);
            return;
        }

        // Update the record with final counts
        await fetch(`${POCKETBASE_URL}/api/collections/usages/records/${usage.id}`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${authToken}` },
            body: JSON.stringify({
                status: "completed",
                part_id: part.id, // Update to the real OpenCode part ID
                tokens_prompt: part.tokens.input,
                tokens_completion: part.tokens.output,
                tokens_reasoning: part.tokens.reasoning || 0,
                tokens_cache_read: part.tokens.cache?.read || 0,
                tokens_cache_write: part.tokens.cache?.write || 0,
                cost: part.cost
            }),
        });
    }

    return {
        name: "pocketcoder-plugin",
        "event": async ({ event }: any) => {
            console.log(`🏰 [PocketCoder] [DEBUG] FULL EVENT: ${JSON.stringify(event)}`);
            console.log(`🏰 [PocketCoder] [DEBUG] EVENT: ${event.type}`);

            if (event.type === "message.part.updated") {
                const part = event.properties.part;
                console.log(`🏰 [PocketCoder] [DEBUG] PART: type=${part.type} status=${part.state?.status}`);
                if (part.type === "tool") {
                    console.log(`🏰 [PocketCoder] [DEBUG] Tool Encountered: ${part.tool} (${part.callID})`);
                    await getOrCreateUsage(part.messageID, part.callID);
                }
            }

            if (event.type === "message.updated") {
                // OpenCode emits message.updated when step finishes
                const parts = event.properties.info.parts || [];
                for (const part of parts) {
                    if (part.type === "step-finish") {
                        await syncUsage(part);
                    }
                }
                const info = event.properties.info;
                if (info.tokens && (info.tokens.input > 0 || info.tokens.output > 0)) {
                    // Sync tokens to usage
                }
            }

            if (event.type === "permission.asked") {
                const info = event.properties.info;
                console.log(`🏰 [PocketCoder] [DEBUG] permission.asked: ${info.id}`);
                const status = await handlePermission(info, false);
                console.log(`🏰 [PocketCoder] [DEBUG] Permission Status: ${status}`);

                if (status === "authorized") {
                    console.log(`🏰 [PocketCoder] [DEBUG] Auto-approving per PocketBase: ${info.id}`);
                    try {
                        if (client.permission?.reply) {
                            await client.permission.reply({ requestID: info.id, reply: "once" });
                        }
                    } catch (e) {
                        console.error(`🏰 [PocketCoder] [DEBUG] Reply failed: ${e}`);
                    }
                }
            }
        },
        "permission.ask": async (info: any, output: any) => {
            console.log(`🏰 [PocketCoder] [DEBUG] permission.ask hook: ${info.id}`);
            const status = await handlePermission(info, true, output);
            output.status = status === "authorized" ? "allow" : "ask";
        }
    };
};
