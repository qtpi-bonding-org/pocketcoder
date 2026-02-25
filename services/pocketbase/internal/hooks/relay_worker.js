/**
 * PocketCoder: Notification Relay Worker
 * 
 * This worker acts as an intelligent dispatcher for both FCM (Google) 
 * and direct UnifiedPush endpoints.
 */

export default {
    async fetch(request, env, ctx) {
        if (request.method !== "POST") {
            return new Response("PocketCoder Relay Only", { status: 405 });
        }

        // 🛡️ Security Check
        const secret = request.headers.get("X-Relay-Secret");
        if (env.PN_RELAY_SECRET && secret !== env.PN_RELAY_SECRET) {
            return new Response("Unauthorized", { status: 401 });
        }

        try {
            const payload = await request.json();
            const { token, title, body, service, click_url } = payload;

            if (service === "fcm") {
                return await handleFCM(token, title, body, click_url, env);
            } else if (service === "unifiedpush") {
                return await handleUnifiedPush(token, title, body, click_url);
            }

            return new Response("Unknown service", { status: 400 });
        } catch (e) {
            return new Response(`Error: ${e.message}`, { status: 500 });
        }
    },
};

/**
 * Dispatches to Google FCM
 */
async function handleFCM(token, title, body, click_url, env) {
    // Note: Requires Firebase Service Account setup in Worker secrets
    // For now, this is a conceptual relay. You would use a library 
    // or direct OAuth2 call to GCM/FCM APIs here.
    console.log(`🔔 Relaying to FCM -> ${token}`);

    // Example: fetch("https://fcm.googleapis.com/v1/projects/...", ...)
    return new Response(JSON.stringify({ success: true, mode: "fcm-placeholder" }), {
        headers: { "Content-Type": "application/json" }
    });
}

/**
 * Dispatches directly to an ntfy endpoint
 */
async function handleUnifiedPush(endpoint, title, body, click_url) {
    const response = await fetch(endpoint, {
        method: "POST",
        headers: {
            "Title": title,
            "Click": click_url || "pocketcoder://",
            "Priority": "high"
        },
        body: body,
    });

    return new Response(await response.text(), {
        status: response.status,
        headers: { "Content-Type": "application/json" }
    });
}
