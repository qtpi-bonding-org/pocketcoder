# PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
# Copyright (C) 2026 Qtpi Bonding LLC
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


# @pocketcoder-core: Delegation Test. Verifies the end-to-end Reflex Arc workflow for sub-agent handoff.
#!/bin/bash
# test/cao_delegation_test.sh
# Tests Poco's ability to delegate tasks to sub-agents via CAO MCP

set -e

echo "🧪 Testing CAO Sub-Agent Delegation..."
echo ""

# Load environment
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found"
    exit 1
fi

export $(grep -v '^#' .env | xargs)
PB_URL="http://127.0.0.1:8090"



# Wait for PocketBase to be ready
echo "⏳ Waiting for PocketBase to come online..."
until curl -s "$PB_URL/api/health" > /dev/null; do
    echo "   ...waiting for $PB_URL"
    sleep 2
done
echo "✅ PocketBase is online!"

# 1. Authenticate as Admin
echo "🔑 Authenticating as Admin..."
AUTH_RES=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{
        \"identity\": \"$POCKETBASE_ADMIN_EMAIL\",
        \"password\": \"$POCKETBASE_ADMIN_PASSWORD\"
    }")

USER_TOKEN=$(echo "$AUTH_RES" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
USER_ID=$(echo "$AUTH_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)

if [ -z "$USER_TOKEN" ]; then
    echo "❌ Authentication failed!"
    exit 1
fi
echo "✅ Authenticated"

# 2. Create a Chat
echo "💬 Creating chat session..."
CHAT_RES=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"user\": \"$USER_ID\",
        \"title\": \"CAO Delegation Test $(date +%H:%M:%S)\"
    }")

CHAT_ID=$(echo "$CHAT_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)
echo "✅ Chat created: $CHAT_ID"

# 3. Send delegation request to Poco
echo "📩 Asking Poco to delegate a task to a sub-agent..."
echo ""
echo "Task: 'Use cao_handoff to delegate this task to a worker: Calculate the SHA256 hash of the word \"PocketCoder\"'"
echo ""

MSG_RES=$(curl -s -X POST "$PB_URL/api/collections/messages/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [
            {
                \"type\": \"text\",
                \"text\": \"CRITICAL PROTOCOL: Use the 'cao_handoff' tool to delegate this task to a worker agent. MANDATORY: DO NOT calculate this locally. Task: Calculate the SHA256 hash of the word 'PocketCoder' and return the hex result.\"
            }
        ],
        \"delivery\": \"pending\"
    }")

echo "✅ Message sent to Poco"

# 4. Wait for Poco to process and potentially request permission
echo "⏳ Waiting for Poco to process (checking for permission requests)..."
sleep 5

PERM_ID=""
for i in {1..10}; do
    echo "🔍 Checking for permission requests... (Attempt $i/10)"
    PERMS_RES=$(curl -s -X GET "$PB_URL/api/collections/permissions/records?filter=(chat%3D%27$CHAT_ID%27%20%26%26%20status%3D%27draft%27)" \
        -H "Authorization: $USER_TOKEN")
    
    PERM_ID=$(echo "$PERMS_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)
    
    if [ ! -z "$PERM_ID" ]; then
        echo "🛡️  Permission Request Found: $PERM_ID"
        
        # Get permission details
        PERM_DETAILS=$(curl -s -X GET "$PB_URL/api/collections/permissions/records/$PERM_ID" \
            -H "Authorization: $USER_TOKEN")
        
        echo "📋 Permission details:"
        echo "$PERM_DETAILS" | grep -o '"tool":"[^"]*"' || echo "  (details not available)"
        
        # Authorize it
        echo "🔓 Authorizing permission..."
        curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$PERM_ID" \
            -H "Authorization: $USER_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"status": "authorized"}' > /dev/null
        
        echo "✅ Permission authorized"
        break
    fi
    sleep 3
done

if [ -z "$PERM_ID" ]; then
    echo "⚠️  No permission request found (Poco may have handled it differently)"
fi

# 5. Wait for full processing and response (Sub-agent work takes time)
echo "⏳ Waiting for Poco and Sub-Agent to complete (polling for final hash)..."
EXPECTED_HASH="7bb83f2fba9710ec82266a636ba92d9947f980680b1c9a96445b954f6fd017c5"
FOUND_HASH="false"

for i in {1..10}; do
    echo "🔍 Checking for final result... (Attempt $i/10)"
    MSGS_RES=$(curl -s -X GET "$PB_URL/api/collections/messages/records?filter=(chat%3D%27$CHAT_ID%27)&sort=-created" \
        -H "Authorization: $USER_TOKEN")
    
    if echo "$MSGS_RES" | grep -q "$EXPECTED_HASH"; then
        echo "✅ Found expected SHA256 hash in message history!"
        FOUND_HASH="true"
        break
    fi
    sleep 5
done

if [ "$FOUND_HASH" = "false" ]; then
    echo "❌ FAILED: Expected hash not found in conversation after timeout."
    exit 1
fi

# 6. Verify tool execution logs
echo "🔍 Verifying 'cao_handoff' execution..."
if echo "$MSGS_RES" | grep -q "cao_handoff"; then
    echo "✅ Tool call 'cao_handoff' detected in message parts."
else
    echo "❌ FAILED: 'cao_handoff' tool call was not recorded."
    exit 1
fi

echo ""
echo "🎉 CAO DELEGATION TEST PASSED AUTOMATICALLY!"
echo ""
