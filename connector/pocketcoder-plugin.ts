/**
 * 🏰 POCKETCODER SOVEREIGN GATEKEEPER
 */
export const PocketCoderPlugin = async ({ client }: any) => {
    console.log("🏰 [PocketCoder] Sovereign Gatekeeper Active");

    // Explicit URLs for Docker network
    const POCKETBASE_URL = "http://pocketbase:8090";
    const AGENT_EMAIL = (typeof process !== 'undefined' ? process.env.AGENT_EMAIL : 'agent@pocketcoder.local');
    const AGENT_PASS = (typeof process !== 'undefined' ? process.env.AGENT_PASSWORD : 'EJ6IiRKdHR8Do6IogD7PApyErxDZhUmp');

    let token: string | null = null;
    const handled = new Set<string>();

    async function getAuthToken() {
        if (token) return token;
        try {
            console.log(`🏰 [PocketCoder] Authenticating with ${POCKETBASE_URL} as ${AGENT_EMAIL}...`);
            const res = await fetch(`${POCKETBASE_URL}/api/collections/users/auth-with-password`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ identity: AGENT_EMAIL, password: AGENT_PASS }),
            });
            if (!res.ok) {
                const text = await res.text();
                throw new Error(`Auth Failed: ${res.status} ${text}`);
            }
            const data = await res.json() as any;
            token = data.token;
            return token;
        } catch (e) {
            console.error("🏰 [PocketCoder] Auth Error:", e);
            return null;
        }
    }

    async function handlePermission(info: any, isHook: boolean, output?: any) {
        if (handled.has(info.id)) return;
        handled.add(info.id);

        console.log(`\n🏰 [PocketCoder] INTERCEPT: ${info.permission || info.type}`);

        try {
            const authToken = await getAuthToken();
            if (!authToken) return;

            const intentRes = await fetch(`${POCKETBASE_URL}/api/collections/executions/records`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${authToken}` },
                body: JSON.stringify({
                    opencode_id: info.id,
                    type: info.permission || info.type,
                    message: info.message || "Requested via OpenCode",
                    patterns: info.patterns || (Array.isArray(info.pattern) ? info.pattern : (info.pattern ? [info.pattern] : [])),
                    session_id: info.sessionID,
                    source: "opencode-plugin",
                    status: "draft"
                }),
            });

            if (!intentRes.ok) {
                console.error(`🏰 [PocketCoder] Database Write Failed: ${await intentRes.text()}`);
                return;
            }

            const intent = await intentRes.json() as any;
            console.log(`🏰 [PocketCoder] Intent ${intent.id} created. Polling for authorization...`);

            const startTime = Date.now();
            while (Date.now() - startTime < 600000) {
                const checkRes = await fetch(`${POCKETBASE_URL}/api/collections/executions/records/${intent.id}`, {
                    headers: { 'Authorization': `Bearer ${authToken}` }
                });
                const check = await checkRes.json() as any;

                if (check.status === 'authorized') {
                    console.log(`🏰 [PocketCoder] ✅ AUTHORIZED: ${intent.id}`);
                    if (isHook && output) {
                        output.status = "allow";
                    } else {
                        await client.postSessionByIdPermissionsByPermissionId({
                            path: { id: info.sessionID, permissionID: info.id },
                            body: { response: "once" }
                        });
                    }
                    return;
                }
                if (check.status === 'denied') {
                    console.log(`🏰 [PocketCoder] ❌ DENIED: ${intent.id}`);
                    if (isHook && output) output.status = "deny";
                    return;
                }
                await new Promise(r => setTimeout(r, 1000));
            }
        } catch (err) {
            console.error("🏰 [PocketCoder] Gatekeeper Error:", err);
        }
    }

    return {
        name: "pocketcoder-plugin",
        "event": async (input: any) => {
            const event = input.event;
            // Pulse logging
            if (event.type.includes("permission") || event.type === "message.part.updated") {
                if (event.type === "permission.asked") {
                    await handlePermission(event.properties, false);
                }
            }
        },
        "permission.ask": async (info: any, output: any) => {
            output.status = "ask";
            await handlePermission(info, true, output);
        }
    };
};
