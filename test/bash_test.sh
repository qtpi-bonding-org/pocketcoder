#!/bin/bash
# test/bash_test.sh
set -e

# 1. Load .env
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found"
    exit 1
fi

export $(grep -v '^#' .env | xargs)
PB_URL="http://127.0.0.1:8090"

# 2. Authenticate
AUTH_RES=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{
        \"identity\": \"$POCKETBASE_ADMIN_EMAIL\",
        \"password\": \"$POCKETBASE_ADMIN_PASSWORD\"
    }")

USER_TOKEN=$(echo "$AUTH_RES" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$USER_TOKEN" ]; then
    echo "❌ Authentication failed!"
    exit 1
fi

# 3. Create Chat
CHAT_RES=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"user\": \"$(echo "$AUTH_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)\", \"title\": \"Bash Test\"}")
CHAT_ID=$(echo "$CHAT_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)
echo "✅ Chat Created: $CHAT_ID"

# 4. Trigger Bash Command
echo "📩 Asking Poco to run a bash command..."
curl -s -X POST "$PB_URL/api/collections/messages/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{ \"type\": \"text\", \"text\": \"Please run the bash command: echo 'BASH_IS_WORKING'\" }],
        \"delivery\": \"pending\"
    }" > /dev/null

echo "⏳ Waiting for Permission Request..."
PERM_ID=""
for i in {1..10}; do
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
    echo "❌ No permission request found. Agent might be failing or ignoring."
    exit 1
fi

# 5. Authorize
echo "🔓 Authorizing..."
curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$PERM_ID" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{ \"status\": \"authorized\" }" > /dev/null

echo "✅ Authorized. Waiting for result..."
sleep 5

# 6. Check Messages for Output
MSGS=$(curl -s -X GET "$PB_URL/api/collections/messages/records?filter=(chat%3D%27$CHAT_ID%27)&sort=-created" \
    -H "Authorization: $USER_TOKEN")

if echo "$MSGS" | grep '"role":"assistant"' | grep -q "BASH_IS_WORKING"; then
    echo "🎉 BASH TEST PASSED! Output found in ASSISTANT response."
else
    echo "❌ BASH TEST FAILED. Output not found."
    echo "Last message content:"
    echo "$MSGS"
    exit 1
fi
