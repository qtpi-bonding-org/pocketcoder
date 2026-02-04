#!/bin/bash
# 🏰 POCKETCODER SOVEREIGN SMOKE TEST
# This script tests the Execution Firewall end-to-end.

set -e

# Load Secrets
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

echo "🚀 Starting PocketCoder Smoke Test..."

# Helper to check result in container logs
check_log() {
    docker-compose exec -T opencode cat /workspace/smoke_test.log
}

# --- STAGE 1: UNGATED WRITE ---
echo "📝 STAGE 1: Ungated Write (Native Speed)"
docker-compose exec -T -w /workspace opencode /bin/sh -c "TERM=dumb NO_COLOR=1 opencode run 'Write ATOMIC_READY to stage1.txt' --model google/gemini-2.0-flash --format json > /workspace/smoke_test.log 2>&1"

if docker-compose exec -T sandbox cat /workspace/stage1.txt 2>/dev/null | grep -q "ATOMIC_READY"; then
    echo "✅ STAGE 1 PASSED."
else
    echo "❌ STAGE 1 FAILED."
    check_log
    exit 1
fi

# --- STAGE 2: GATED EXECUTION ---
echo "⚖️  STAGE 2: Gated Execution (Firewall)"
# We MUST background this because the tool will hang at the approval prompt
docker-compose exec -T -w /workspace opencode /bin/sh -c "TERM=dumb NO_COLOR=1 nohup opencode run 'Run command: echo FIREWALL_RELEASED' --model google/gemini-2.0-flash --format json > /workspace/smoke_test.log 2>&1 &"

echo "⏳ Polling for Intent Sign-off..."

docker-compose exec -T -e ADMIN_PASSWORD="$ADMIN_PASSWORD" opencode node -e '
(async () => {
    const adminPass = process.env.ADMIN_PASSWORD;
    const maxRetries = 10;
    const delay = 1000;

    for (let i = 0; i < maxRetries; i++) {
        try {
            // 1. Authenticate as Admin
            const authRes = await fetch("http://gateway:8090/api/collections/users/auth-with-password", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ identity: "admin@pocketcoder.local", password: adminPass })
            });
            const authJson = await authRes.json();
            const token = authJson.token;
            if (!token) { await new Promise(r => setTimeout(r, delay)); continue; }
            
            // 2. Look for Draft Intent
            const listRes = await fetch("http://gateway:8090/api/collections/executions/records?filter=(status=\"draft\")&sort=-created", {
                headers: { "Authorization": "Bearer " + token }
            });
            const listJson = await listRes.json();
            
            if (listJson.items && listJson.items.length > 0) {
                const draft = listJson.items[0];
                console.log("\n✅ FOUND INTENT:", draft.id);
                console.log("✍️  Signing execution...");
                
                // 3. Authorize the Intent
                await fetch("http://gateway:8090/api/collections/executions/records/" + draft.id, {
                    method: "PATCH",
                    headers: { "Content-Type": "application/json", "Authorization": "Bearer " + token },
                    body: JSON.stringify({ status: "authorized" })
                });
                console.log("🟢 EXECUTION AUTHORIZED.");
                process.exit(0);
            }
        } catch (e) { }
        process.stdout.write(".");
        await new Promise(r => setTimeout(r, delay));
    }
    console.log("\n❌ TIMEOUT: No draft execution found in PocketBase.");
    process.exit(1);
})()
'

echo "🏁 Final Verification..."
sleep 3
if check_log | grep -q "FIREWALL_RELEASED"; then
    echo "✅ STAGE 2 PASSED: Gated command executed successfully!"
    echo "✨ POCKETCODER SMOKE TEST SUCCESSFUL! ✨"
else
    echo "❌ STAGE 2 FAILED: Result string not found in logs."
    check_log
    exit 1
fi
