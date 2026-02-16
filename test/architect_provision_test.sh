#!/bin/bash
# test/architect_provision_test.sh
# Phase 1: Verify Poco can provision the Terraform MCP server and write the agent profile.

set -e

# 1. Load Configuration
if [ ! -f .env ]; then echo "❌ .env not found"; exit 1; fi
export $(grep -v '^#' .env | xargs)
PB_URL="http://127.0.0.1:8090"

# 2. Authenticate
echo "🔑 Logging in..."
AUTH_RES=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$POCKETBASE_ADMIN_EMAIL\",\"password\":\"$POCKETBASE_ADMIN_PASSWORD\"}")
TOKEN=$(echo "$AUTH_RES" | jq -r '.token')
USER_ID=$(echo "$AUTH_RES" | jq -r '.record.id')

# 3. Create Chat
echo "💬 Creating Chat..."
CHAT_RES=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"user\":\"$USER_ID\",\"title\":\"Phase 1: Provisioning Test\"}")
CHAT_ID=$(echo "$CHAT_RES" | jq -r '.id')
echo "✅ Chat Created: $CHAT_ID"

# 4. Send Prompt (Provisioning Only)
# Note: We explicitly tell Poco to STOP after preparing.
PROMPT="Poco, use your 'architect' skill to provision the terraform-mcp-server binary into /usr/local/bin and write the 'tf_expert' agent profile. 

MANDATORY: We are just preparing the workshop. DO NOT attempt to handoff or call the subagent yet. Just confirm once the files are ready."

echo "📩 Sending Prompt..."
curl -s -X POST "$PB_URL/api/collections/messages/records" \
    -H "Authorization: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"chat\":\"$CHAT_ID\",\"role\":\"user\",\"parts\":[{\"type\":\"text\",\"text\":\"$PROMPT\"}],\"delivery\":\"pending\"}" > /dev/null

# 5. Polling & Auto-Approval Loop
echo "⏳ Entering Approval Loop..."
START_TIME=$(date +%s)
TIMEOUT=600 # 10 minutes

while true; do
    ELAPSED=$(( $(date +%s) - START_TIME ))
    if [ $ELAPSED -gt $TIMEOUT ]; then echo "❌ TIMEOUT"; exit 1; fi

    # Check for DRAFTS
    DRAFTS=$(curl -s -X GET "$PB_URL/api/collections/permissions/records?filter=(status='draft'%26%26chat='$CHAT_ID')" \
        -H "Authorization: $TOKEN" | jq -r '.items[].id')
    
    for ID in $DRAFTS; do
        DETAILS=$(curl -s -X GET "$PB_URL/api/collections/permissions/records/$ID" -H "Authorization: $TOKEN")
        TOOL=$(echo "$DETAILS" | jq -r '.tool')
        echo "🔓 Authorizing $TOOL Intent: $ID"
        curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$ID" \
            -H "Authorization: $TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"status\":\"authorized\"}" > /dev/null
    done

    # Check Sandbox for success markers
    BINARY_EXISTS=$(docker exec pocketcoder-sandbox ls /usr/local/bin/terraform-mcp-server 2>/dev/null || true)
    PROFILE_EXISTS=$(docker exec pocketcoder-sandbox ls /root/.aws/cli-agent-orchestrator/agent-store/tf_expert.md 2>/dev/null || true)

    if [ ! -z "$BINARY_EXISTS" ] && [ ! -z "$PROFILE_EXISTS" ]; then
        echo "🎉 SUCCESS: Binary and Profile detected in sandbox!"
        break
    fi

    echo -n "."
    sleep 5
done

# 6. Final Verification
echo ""
echo "🔍 Final Check:"
docker exec pocketcoder-sandbox ls -l /usr/local/bin/terraform-mcp-server
docker exec pocketcoder-sandbox cat /root/.aws/cli-agent-orchestrator/agent-store/tf_expert.md
echo "🏁 Phase 1 Test Passed."
