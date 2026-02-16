#!/bin/bash
# test/bash_permission_sanity.sh
# 1:1 clone of working permission_flow_full.sh but testing BASH resumption.

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
    -d "{ \"user\": \"$USER_ID\", \"title\": \"BASH Sanity $(date +%H:%M:%S)\" }")
CHAT_ID=$(echo "$CHAT_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)
echo "✅ Chat Created: $CHAT_ID"

# 4. Trigger BASH Prompt
echo "📩 Sending 'BASH' prompt..."
curl -s -X POST "$PB_URL/api/collections/messages/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{ \"type\": \"text\", \"text\": \"Please run this command: echo 'BASH_WORKS' > /tmp/sanity.txt\" }],
        \"delivery\": \"pending\"
    }" > /dev/null

# 5. Poll for Permission
PERM_ID=""
for i in {1..15}; do
    echo "🔍 Checking for pending permissions... (Attempt $i/15)"
    PERMS_RES=$(curl -s -X GET "$PB_URL/api/collections/permissions/records?filter=(chat%3D%27$CHAT_ID%27%20%26%26%20status%3D%27draft%27)" \
        -H "Authorization: $USER_TOKEN")
    PERM_ID=$(echo "$PERMS_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)
    if [ ! -z "$PERM_ID" ]; then
        echo "🛡️  Permission Request Found: $PERM_ID"
        break
    fi
    sleep 2
done

if [ -z "$PERM_ID" ]; then echo "❌ No permission request found"; exit 1; fi

# 6. Authorize
echo "🔓 Authorizing $PERM_ID..."
curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$PERM_ID" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{ \"status\": \"authorized\" }" > /dev/null

# 7. Verification
echo "⏳ Waiting for AI to resume..."
sleep 10

if docker exec pocketcoder-sandbox cat /tmp/sanity.txt | grep -q 'BASH_WORKS'; then
    echo "🎉 SUCCESS: BASH Resumption Works!"
else
    echo "❌ Failure: /tmp/sanity.txt not found or incorrect."
    exit 1
fi
