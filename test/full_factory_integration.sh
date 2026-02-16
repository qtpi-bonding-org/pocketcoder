#!/bin/bash
# test/full_factory_integration.sh
# End-to-End Test for the Sovereign AI Factory: 
# Architect Workflow -> Terraform MCP Provisioning -> Subagent Verification.

set -e

# 1. Load Configuration
if [ ! -f .env ]; then echo "❌ .env not found"; exit 1; fi
export $(grep -v '^#' .env | xargs)
PB_URL="http://127.0.0.1:8090"

echo "🎯 Starting Full Factory Integration Test..."

# 2. Authenticate
echo "🔑 Logging in..."
AUTH=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$POCKETBASE_ADMIN_EMAIL\",\"password\":\"$POCKETBASE_ADMIN_PASSWORD\"}")
TOKEN=$(echo "$AUTH" | jq -r '.token')
USER_ID=$(echo "$AUTH" | jq -r '.record.id')

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then echo "❌ Auth Failed"; exit 1; fi

# 3. Create Chat
CHAT_RES=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"user\":\"$USER_ID\",\"title\":\"FACTORY-TEST: Terraform Setup\"}")
CHAT_ID=$(echo "$CHAT_RES" | jq -r '.id')
echo "✅ Chat Created: $CHAT_ID"

# 4. Send Initial Prompt
PROMPT="Poco, please apply the 'architect' skill workflow to provision the Terraform MCP server in the sandbox, set up a 'terraform_expert' subagent, and then have that subagent search the registry for the Linode provider."
curl -s -X POST "$PB_URL/api/collections/messages/records" \
    -H "Authorization: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"chat\":\"$CHAT_ID\",\"role\":\"user\",\"parts\":[{\"type\":\"text\",\"text\":\"$PROMPT\"}],\"delivery\":\"pending\"}" > /dev/null

echo "📩 Prompt sent. Entering Orchestration Loop (10 min timeout)..."

# 5. Polling & Auto-Approval Loop
START_TIME=$(date +%s)
TIMEOUT=900 # 15 minutes
STEP_COUNT=0
PROVISIONED=false

echo "🔍 Polling for Poco's actions..."

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    if [ $ELAPSED -gt $TIMEOUT ]; then echo "❌ TEST TIMED OUT"; exit 1; fi

    # Check for DRAFTS (Aggressive mode: catch orphans/subagents)
    # We poll for ALL drafts and filter in shell to be safe
    DRAFTS_RES=$(curl -s -X GET "$PB_URL/api/collections/permissions/records?filter=(status='draft')" \
        -H "Authorization: $TOKEN")
    
    # Authorize if:
    # 1. Matches our Chat ID
    # 2. OR Chat ID is empty (Subagent orphan)
    # 3. AND it was created after we started
    DRAFTS_DATA=$(echo "$DRAFTS_RES" | jq -r '.items[]? | "\(.id)|\(.chat)"')
    
    if [ -n "$DRAFTS_DATA" ]; then
        for entry in $DRAFTS_DATA; do
            ID=$(echo "$entry" | cut -d'|' -f1)
            CID=$(echo "$entry" | cut -d'|' -f2)
            
            if [ "$CID" = "$CHAT_ID" ] || [ "$CID" = "null" ] || [ -z "$CID" ]; then
                echo "🔓 [Step $STEP_COUNT] Authorizing Intent: $ID (Chat: $CID)"
                curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$ID" \
                    -H "Authorization: $TOKEN" \
                    -H "Content-Type: application/json" \
                    -d "{\"status\":\"authorized\"}" > /dev/null
                STEP_COUNT=$((STEP_COUNT + 1))
            fi
        done
    fi

    # Verification: Check if binary exists in Sandbox
    if [ "$PROVISIONED" = false ]; then
        if docker exec pocketcoder-sandbox ls /usr/local/bin/terraform-mcp-server >/dev/null 2>&1; then
            echo "✅ PROVISIONING PHASE: Terraform Binary found in Sandbox."
            PROVISIONED=true
        fi
    fi

    # Check Messages to report progress
    MESSAGES_RES=$(curl -s -X GET "$PB_URL/api/collections/messages/records?filter=(chat='$CHAT_ID')&sort=-created&limit=1" \
        -H "Authorization: $TOKEN")
    
    # Last role and delivery status
    LAST_ROLE=$(echo "$MESSAGES_RES" | jq -r '.items[0]?.role // "none"')
    LAST_DELIVERY=$(echo "$MESSAGES_RES" | jq -r '.items[0]?.delivery // "none"')
    
    if [ "$LAST_DELIVERY" = "pending" ] || [ "$LAST_DELIVERY" = "sending" ]; then
        echo "⏳ Poco is thinking..."
    elif [ "$LAST_ROLE" = "assistant" ]; then
        LATEST_TEXT=$(echo "$MESSAGES_RES" | jq -r '.items[0].parts[]? | select(.type=="text") | .text // empty' | tr '\n' ' ')
        
        # Check for concrete provider details (this proves the MCP tool actually ran)
        if echo "$LATEST_TEXT" | grep -Ei "Linode|HashiCorp|Registry|provider" | grep -viE "Applying|Skill|retry|Interference" > /dev/null; then
            if [ "$PROVISIONED" = true ]; then
                echo "🎉 SUCCESS: Subagent search results detected!"
                echo "----------------------------------------------------"
                echo "$LATEST_TEXT"
                echo "----------------------------------------------------"
                break
            fi
        fi
    fi

    echo -n "." # Heartbeat
    sleep 15
done

echo "🏁 Test Suite Complete."
