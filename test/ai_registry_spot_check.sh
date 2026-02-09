#!/bin/bash
# test/ai_registry_spot_check.sh

POCKETBASE_URL="http://127.0.0.1:8090"

# Load from .env
if [ -f .env ]; then
    ADMIN_EMAIL=$(grep "^POCKETBASE_SUPERUSER_EMAIL=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
    ADMIN_PASS=$(grep "^POCKETBASE_SUPERUSER_PASSWORD=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
else
    echo "❌ .env file not found."
    exit 1
fi

echo "🔐 Authenticating as Admin..."
AUTH_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$ADMIN_EMAIL\", \"password\":\"$ADMIN_PASS\"}")

ADMIN_TOKEN=$(echo $AUTH_RES | jq -r '.token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" == "null" ]; then
    echo "❌ Admin Auth Failed"
    echo "Response: $AUTH_RES"
    exit 1
fi

echo "✅ Authenticated."

# 1. Create Prompt
echo "📝 Creating Prompt..."
PROMPT_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ai_prompts/records" \
    -H "Authorization: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Spot Check Prompt\", \"body\":\"This is a test prompt content.\"}")
PROMPT_ID=$(echo $PROMPT_RES | jq -r '.id')
echo "✅ Prompt ID: $PROMPT_ID"

# 2. Create Model
echo "🤖 Creating Model..."
MODEL_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ai_models/records" \
    -H "Authorization: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Spot Check Model\", \"identifier\":\"anthropic/claude-3-5-sonnet\"}")
MODEL_ID=$(echo $MODEL_RES | jq -r '.id')
echo "✅ Model ID: $MODEL_ID"

# 3. Create Agent (Poco Orchestrator)
echo "💂 Creating Poco Agent..."
AGENT_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ai_agents/records" \
    -H "Authorization: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\":\"spot_check_orchestrator\",
        \"is_init\": true,
        \"mode\": \"primary\",
        \"prompt\": \"$PROMPT_ID\",
        \"model\": \"$MODEL_ID\"
    }")
AGENT_ID=$(echo $AGENT_RES | jq -r '.id')

if [ -z "$AGENT_ID" ] || [ "$AGENT_ID" == "null" ]; then
    echo "❌ Agent Creation Failed"
    echo "Response: $AGENT_RES"
    exit 1
fi
echo "✅ Agent ID: $AGENT_ID"

# 4. Verify Assembly (Go Hook)
echo "🔍 Verifying Assembly in PocketBase..."
sleep 2 # Wait for hook to run
AGENT_DETAIL=$(curl -s "$POCKETBASE_URL/api/collections/ai_agents/records/$AGENT_ID" \
    -H "Authorization: $ADMIN_TOKEN")

CONFIG=$(echo $AGENT_DETAIL | jq -r '.config')

if [ -z "$CONFIG" ] || [ "$CONFIG" == "null" ] || [ "$CONFIG" == "" ]; then
    echo "❌ Assembly Failed: config field is empty"
    echo "Agent Detail: $AGENT_DETAIL"
    exit 1
fi
echo "✅ Assembly Verified: Configuration bundle generated."

# 5. Verify Synchronization (Relay)
echo "🚀 Verifying Synchronization (Poco Target)..."
sleep 2 # Wait for relay to sync
SYNC_CHECK=$(docker exec pocketcoder-opencode ls -la /workspace/.opencode/agents/spot_check_orchestrator.md 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Synchronization Verified: File exists in Poco agents directory."
else
    echo "❌ Synchronization Failed: File not found in Poco agents directory."
    exit 1
fi

# 6. Test Worker Toggle (CAO Target)
echo "🔄 Toggling Agent to Worker..."
curl -s -X PATCH "$POCKETBASE_URL/api/collections/ai_agents/records/$AGENT_ID" \
    -H "Authorization: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"is_init\": false}" > /dev/null

sleep 3 # Wait for relay to sync
WORKER_CHECK=$(docker exec pocketcoder-opencode ls -la /workspace/sandbox/cao/agent_store/spot_check_orchestrator.md 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Worker Toggle Verified: File synced to Sandbox agent store."
else
    echo "❌ Worker Toggle Failed: File not found in Sandbox agent store."
    exit 1
fi

echo "🏁 Phase 1 Spot Check PASSED!"
