/**
 * 🏰 POCKETCODER SOVEREIGN PLUGIN (GATEKEEPER)
 * 
 * This plugin is a PURE INTERCEPTOR. 
 * Every permission request is sent to PocketBase. 
 * PocketBase is the SOVEREIGN AUTHORITY on whether to allow or draft.
 */

export const PocketCoderPlugin = async ({ client }: any) => {
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

    async function handlePermission(info: any, isHook: boolean, output?: any) {
        if (handled.has(info.id)) return;
        handled.add(info.id);

        console.log(`\n🏰 [PocketCoder] REQUEST: ${info.permission || info.type} for ${info.patterns?.join(', ') || info.pattern}`);

        try {
            const authToken = await getAuthToken();
            if (!authToken) return;

            // 1. Create permission record (matches OpenCode PermissionNext.Request)
            const permissionRes = await fetch(`${POCKETBASE_URL}/api/collections/permissions/records`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${authToken}` },
                body: JSON.stringify({
                    opencode_id: info.id,
                    session_id: info.sessionID,
                    permission: info.permission || info.type,
                    patterns: info.patterns || (Array.isArray(info.pattern) ? info.pattern : (info.pattern ? [info.pattern] : [])),
                    metadata: info.metadata || {},
                    always: info.always || [],
                    message_id: info.tool?.messageID || info.messageID,
                    call_id: info.tool?.callID || info.callID,
                    source: "opencode-plugin",
                    status: "draft", // Backend will auto-authorize if not bash
                    message: info.message || "Requested via OpenCode"
                }),
            });

            if (!permissionRes.ok) {
                console.error(`🏰 [PocketCoder] Database Error: ${await permissionRes.text()}`);
                return;
            }

            let permission = await permissionRes.json() as any;
            console.log(`🏰 [PocketCoder] Recorded Permission ${permission.id} (Status: ${permission.status})`);

            // 2. Poll/Wait for Authorization
            const startTime = Date.now();
            while (Date.now() - startTime < 600000) {
                // If the backend auto-authorized it on CREATE, we might already be done.
                if (permission.status === 'authorized') {
                    console.log(`🏰 [PocketCoder] ✅ AUTHORIZED: ${permission.id}`);
                    if (isHook && output) {
                        output.status = "allow";
                    } else {
                        await client.postSessionByIdPermissionsByPermissionId({
                            path: { id: info.sessionID, permissionID: info.id },
                            body: { response: "once" }
                        }).catch(() => { });
                    }
                    return;
                }

                if (permission.status === 'denied') {
                    console.log(`🏰 [PocketCoder] ❌ DENIED: ${permission.id}`);
                    if (isHook && output) output.status = "deny";
                    return;
                }

                // Check for updates
                const checkRes = await fetch(`${POCKETBASE_URL}/api/collections/permissions/records/${permission.id}`, {
                    headers: { 'Authorization': `Bearer ${authToken}` }
                });
                permission = await checkRes.json() as any;

                await new Promise(r => setTimeout(r, 1000));
            }

            if (isHook && output) output.status = "deny";

        } catch (err) {
            console.error("🏰 [PocketCoder] Gatekeeper Error:", err);
            if (isHook && output) output.status = "deny";
        }
    }

    return {
        name: "pocketcoder-plugin",
        "event": async ({ event }: any) => {
            if (event.type === "permission.asked") {
                await handlePermission(event.properties, false);
            }
        },
        "permission.ask": async (info: any, output: any) => {
            output.status = "ask";
            await handlePermission(info, true, output);
        }
    };
};
