#!/bin/bash
# test/automatic_resumption_check.sh
# Goal: Verify if OpenCode resumes automatically when authorized in the DB.

set -e
if [ ! -f .env ]; then echo "❌ .env not found"; exit 1; fi
export $(grep -v '^#' .env | xargs)
PB_URL="http://127.0.0.1:8090"

echo "🧪 Starting Automatic Resumption Check..."

# 1. Auth & Chat
AUTH=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" -H "Content-Type: application/json" -d "{\"identity\":\"$POCKETBASE_ADMIN_EMAIL\",\"password\":\"$POCKETBASE_ADMIN_PASSWORD\"}")
TOKEN=$(echo "$AUTH" | jq -r '.token')
USER_ID=$(echo "$AUTH" | jq -r '.record.id')
CHAT_ID=$(curl -s -X POST "$PB_URL/api/collections/chats/records" -H "Authorization: $TOKEN" -H "Content-Type: application/json" -d "{\"user\":\"$USER_ID\",\"title\":\"Resumption Test\"}" | jq -r '.id')

echo "✅ Chat Created: $CHAT_ID"

# 2. Trigger Command
TOKEN_STR="AUTO_RESUME_$(date +%s)"
echo "📩 Asking Poco to run a command with token: $TOKEN_STR"
curl -s -X POST "$PB_URL/api/collections/messages/records" -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
    -d "{\"chat\":\"$CHAT_ID\",\"role\":\"user\",\"parts\":[{\"type\":\"text\",\"text\":\"Please run: echo '$TOKEN_STR' > /tmp/auto_resume_test.txt\"}],\"delivery\":\"pending\"}" > /dev/null

# 3. Wait for Draft
echo "⏳ Waiting for Draft Permission..."
PERM_ID=""
for i in {1..15}; do
    PERMS=$(curl -s -X GET "$PB_URL/api/collections/permissions/records?filter=(chat='$CHAT_ID'%26%26status='draft')" -H "Authorization: $TOKEN")
    PERM_ID=$(echo "$PERMS" | jq -r '.items[0].id')
    if [ "$PERM_ID" != "null" ] && [ -n "$PERM_ID" ]; then break; fi
    sleep 2
done

if [ -z "$PERM_ID" ] || [ "$PERM_ID" == "null" ]; then echo "❌ No draft found"; exit 1; fi
echo "🛡️  Draft Found: $PERM_ID"

# 4. Authorize ONLY (No manual nudge)
echo "🔓 Authorizing record in Database ONLY..."
curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$PERM_ID" -H "Authorization: $TOKEN" -H "Content-Type: application/json" -d "{\"status\":\"authorized\"}" > /dev/null

# 5. Verification Loop
echo "🧐 Checking for execution in Sandbox (Automatic Resumption)..."
for i in {1..10}; do
    if docker exec pocketcoder-sandbox cat /tmp/auto_resume_test.txt 2>/dev/null | grep -q "$TOKEN_STR"; then
        echo "🎉 SUCCESS: Automatic Resumption works! Nudge NOT required."
        exit 0
    fi
    echo -n "."
    sleep 3
done

echo ""
echo "❌ FAILURE: Automatic Resumption failed. The system is hanging despite authorization."
# Check if Poco at least recognized the auth (but maybe the tool failed)
MESSAGES=$(curl -s -X GET "$PB_URL/api/collections/messages/records?filter=(chat='$CHAT_ID')" -H "Authorization: $TOKEN")
if echo "$MESSAGES" | grep -q "Reflex Arc"; then
    echo "⚠️ Poco resumed but something else went wrong."
else
    echo "💀 Poco is still waiting/idling. The Relay hook is broken."
fi
exit 1
