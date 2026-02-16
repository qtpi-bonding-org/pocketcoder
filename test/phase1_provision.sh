#!/bin/bash
# test/phase1_provision.sh
# SIMPLE Phase 1: Verify Poco can provision Terraform MCP via Atomic Bash.
# Based on the proven permission_flow_full.sh template.

set -e

# 1. Load .env
if [ ! -f .env ]; then echo "❌ .env not found"; exit 1; fi
export $(grep -v '^#' .env | xargs)
PB_URL="http://127.0.0.1:8090"

# 2. Authenticate
AUTH_RES=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{ \"identity\": \"$POCKETBASE_ADMIN_EMAIL\", \"password\": \"$POCKETBASE_ADMIN_PASSWORD\" }")
USER_TOKEN=$(echo "$AUTH_RES" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
USER_ID=$(echo "$AUTH_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)

# 3. Create Chat
CHAT_RES=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{ \"user\": \"$USER_ID\", \"title\": \"Phase 1: Binary Provisioning\" }")
CHAT_ID=$(echo "$CHAT_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)
echo "✅ Chat Created: $CHAT_ID"

echo "⏳ Warming up Relay (5s)..."
sleep 5

# 4. Trigger Provisioning (ATOMIC COMMAND)
# We install the binary AND write the agent profile in one go.
PROMPT="Please run this exact command to equip the sandbox: curl -L https://releases.hashicorp.com/terraform-mcp-server/0.4.0/terraform-mcp-server_0.4.0_linux_amd64.zip -o /tmp/tf.zip && unzip -o /tmp/tf.zip -d /tmp/ && mv /tmp/terraform-mcp-server /usr/local/bin/terraform-mcp-server && chmod +x /usr/local/bin/terraform-mcp-server && mkdir -p /root/.aws/cli-agent-orchestrator/agent-store/ && printf -- \"---\\nname: tf_expert\\ndescription: Terraform specialist\\nmcpServers:\\n  terraform:\\n    command: terraform-mcp-server\\n---\\nI am the Terraform specialist. I use the terraform-mcp-server to manage infrastructure. Use the 'terraform' tool to interact with me.\\n\" > /root/.aws/cli-agent-orchestrator/agent-store/tf_expert.md && echo 'INSTALL_DONE'"

echo "📩 Sending 'Provision binary + profile' prompt..."
JSON_BODY=$(jq -n --arg chat "$CHAT_ID" --arg text "$PROMPT" \
    '{chat: $chat, role: "user", parts: [{type: "text", text: $text}], delivery: "pending"}')

MSG_RES=$(curl -s -X POST "$PB_URL/api/collections/messages/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON_BODY")

MSG_ID=$(echo "$MSG_RES" | jq -r .id)
if [ -z "$MSG_ID" ] || [ "$MSG_ID" == "null" ]; then
    echo "❌ Message creation failed: $MSG_RES"
    exit 1
fi
echo "✅ Message Created: $MSG_ID"

# 5. Continuous Authorization Loop
echo "�️ Starting Auto-Approve Loop (60s)..."
END_TIME=$((SECONDS + 60))

while [ $SECONDS -lt $END_TIME ]; do
    PERMS_RES=$(curl -s -X GET "$PB_URL/api/collections/permissions/records?filter=(chat%3D%27$CHAT_ID%27%20%26%26%20status%3D%27draft%27)" \
        -H "Authorization: $USER_TOKEN")
    
    # Extract ALL draft IDs
    DRAFT_IDS=$(echo "$PERMS_RES" | jq -r '.items[].id')
    
    if [ ! -z "$DRAFT_IDS" ] && [ "$DRAFT_IDS" != "null" ]; then
        for PERM_ID in $DRAFT_IDS; do
            ITEM=$(echo "$PERMS_RES" | jq -c ".items[] | select(.id == \"$PERM_ID\")")
            TYPE=$(echo "$ITEM" | jq -r ".permission")
            OC_ID=$(echo "$ITEM" | jq -r ".opencode_id")
            
            echo "🔓 Authorizing $TYPE Request ($OC_ID)..."
            
            # A. Update PocketBase
            curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$PERM_ID" \
                -H "Authorization: $USER_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{ \"status\": \"authorized\" }" > /dev/null
            
            # B. DIRECT NOTIFY OpenCode (Manual Override)
            # We must run this INSIDE the network (via pocketbase container)
            docker exec pocketcoder-pocketbase curl -v -X POST "http://opencode:3000/permission/$OC_ID/reply" \
                -H "Content-Type: application/json" \
                -d '{"reply":"once"}'
        done
        # Reset timeout if we processed something
        END_TIME=$((SECONDS + 45))
    fi
    
    # Check if we saw an INSTALL_DONE in assistant messages?
    # Or just wait for the binary to appear.
    if docker exec pocketcoder-sandbox ls /usr/local/bin/terraform-mcp-server > /dev/null 2>&1; then
        echo "🎉 Binary Detected!"
        break
    fi

    sleep 2
done

# 7. Verification
echo "⏳ Waiting for install completion..."
sleep 15

BINARY_OK=""
PROFILE_OK=""

if docker exec pocketcoder-sandbox ls /usr/local/bin/terraform-mcp-server > /dev/null 2>&1; then
    BINARY_OK="YES"
fi

if docker exec pocketcoder-sandbox ls /root/.aws/cli-agent-orchestrator/agent-store/tf_expert.md > /dev/null 2>&1; then
    PROFILE_OK="YES"
fi

if [ "$BINARY_OK" == "YES" ] && [ "$PROFILE_OK" == "YES" ]; then
    echo "🎉 SUCCESS: Phase 1 complete. Binary and Profile verified!"
    exit 0
else
    echo "❌ Failure:"
    [ -z "$BINARY_OK" ] && echo "  - Binary missing"
    [ -z "$PROFILE_OK" ] && echo "  - Profile missing"
    exit 1
fi
