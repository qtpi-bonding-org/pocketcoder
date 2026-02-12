#!/bin/bash
# test/permission_flow_full.sh
# Automates the full Permission flow: 
# Auth → Chat Creation → AI Message → Permission Detection → User Authorization → Success

set -e

# 1. Load .env
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found in root directory."
    exit 1
fi

echo "📂 Loading configuration from .env..."
export $(grep -v '^#' .env | xargs)

PB_URL="http://127.0.0.1:8090"
OC_URL="http://127.0.0.1:3000"

# 2. Authenticate as User
echo "🔑 Logging into PocketBase as Human ($POCKETBASE_ADMIN_EMAIL)..."
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
    echo "$AUTH_RES"
    exit 1
fi
echo "✅ Logged in. Token retrieved."

# 3. Create a Chat
echo "💬 Creating a new Chat..."
CHAT_RES=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"user\": \"$USER_ID\",
        \"title\": \"Auto-Test Gatekeeper $(date +%H:%M:%S)\"
    }")

CHAT_ID=$(echo "$CHAT_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)
echo "✅ Chat Created: $CHAT_ID ($CHAT_RES)"

# 4. Trigger AI Message
# We create a message in PB, which the Relay will pick up.
echo "📩 Sending 'Write File' prompt to Relay via PocketBase..."
MSG_RES=$(curl -s -X POST "$PB_URL/api/collections/messages/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [
            { \"type\": \"text\", \"text\": \"Please write a file named automated_test.txt with content 'Flow Complete'\" }
        ],
        \"delivery\": \"pending\"
    }")

echo "✅ User message created: $MSG_RES"
echo "⏳ Waiting for Relay to process and ask for permission..."

# 5. Poll for Permission Request
PERM_ID=""
for i in {1..10}; do
    echo "🔍 Checking for pending permissions... (Attempt $i/10)"
    PERMS_RES=$(curl -s -X GET "$PB_URL/api/collections/permissions/records?filter=(chat%3D%27$CHAT_ID%27%20%26%26%20status%3D%27draft%27)" \
        -H "Authorization: $USER_TOKEN")
    
    PERM_ID=$(echo "$PERMS_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)
    
    if [ ! -z "$PERM_ID" ]; then
        echo "🛡️  Permission Request Found: $PERM_ID"
        break
    fi
    sleep 2
done

if [ -z "$PERM_ID" ]; then
    echo "❌ No permission request found. Did the Relay fail?"
    exit 1
fi

# 6. Authorize the Permission
echo "🔓 Authorizing permission $PERM_ID..."
curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$PERM_ID" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{ \"status\": \"authorized\" }" > /dev/null

echo "✅ Authorized. The Relay should now tell AI to proceed."

# 7. Final Verification
echo "⏳ Waiting for AI to complete action..."
sleep 5

echo "🏁 Checking if file exists in sandbox workspace..."
if docker exec pocketcoder-opencode ls /workspace/automated_test.txt > /dev/null 2>&1; then
    CONTENT=$(docker exec pocketcoder-opencode cat /workspace/automated_test.txt)
    echo "🎉 SUCCESS! File created with content: '$CONTENT'"
else
    echo "❌ Failure: File automated_test.txt not found in workspace."
    exit 1
fi
