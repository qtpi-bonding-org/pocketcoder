#!/bin/bash
# test/poco_bash_proxy_test.sh
# Checks if Poco (OpenCode) can run a bash command through the Proxy.
# Inherits patterns from permission_flow_full.sh

set -e

# 1. Load .env
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found."
    exit 1
fi

echo "📂 Loading configuration from .env..."
export $(grep -v "^#" .env | xargs)

PB_URL="http://127.0.0.1:8090"

# 2. Wait for PocketBase to be ready
echo "⏳ Waiting for PocketBase to be ready..."
for i in {1..30}; do
    if curl -s -o /dev/null "$PB_URL/api/health"; then
        echo "✅ PocketBase is UP"
        break
    fi
    if [ $i -eq 30 ]; then echo "❌ PocketBase timeout"; exit 1; fi
    sleep 1
done

# 3. Authenticate as User
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

# 4. Create a Chat
echo "💬 Creating a new Chat..."
CHAT_RES=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"user\": \"$USER_ID\",
        \"title\": \"Poco Proxy Integration Test $(date +%H:%M:%S)\"
    }")

CHAT_ID=$(echo "$CHAT_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)
echo "✅ Chat Created: $CHAT_ID"

# 5. Trigger Bash Command
VERIFY_STRING="POCO_PROXY_TEST_$(date +%s)"
echo "📩 Sending bash request to Poco (Verify string: $VERIFY_STRING)..."

curl -s -X POST "$PB_URL/api/collections/messages/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [ { \"type\": \"text\", \"text\": \"Please run this command: echo $VERIFY_STRING\" } ],
        \"delivery\": \"pending\"
    }" > /dev/null

echo "⏳ Waiting for Permission Request..."
PERM_ID=""
for i in {1..20}; do
    echo "🔍 Checking for pending permissions... (Attempt $i/20)"
    # Using the same filter pattern as permission_flow_full.sh
    PERMS_RES=$(curl -s -X GET "$PB_URL/api/collections/permissions/records?filter=(chat%3D%27$CHAT_ID%27%20%26%26%20status%3D%27draft%27)" \
        -H "Authorization: $USER_TOKEN")
    
    PERM_ID=$(echo "$PERMS_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)
    
    if [ ! -z "$PERM_ID" ]; then
        echo "🛡️  Permission Request Found: $PERM_ID"
        break
    fi
    sleep 3
done

if [ -z "$PERM_ID" ]; then
    echo "❌ No permission request found. Ensure Relay is running."
    exit 1
fi

# 6. Authorize the Permission
echo "🔓 Authorizing permission $PERM_ID..."
curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$PERM_ID" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{ \"status\": \"authorized\" }" > /dev/null

echo "⏳ Waiting for AI to execute and Proxy to log the command..."
SUCCESS=0
for i in {1..15}; do
    if docker logs pocketcoder-proxy 2>&1 | grep "$VERIFY_STRING" > /dev/null; then
        echo "✅ SUCCESS: Command detected in Proxy logs!"
        SUCCESS=1
        break
    fi
    sleep 2
done

if [ $SUCCESS -eq 0 ]; then
    echo "❌ FAILURE: Command did not reach Proxy logs."
    echo "🔍 Recent Proxy Logs:"
    docker logs pocketcoder-proxy | tail -n 10
    exit 1
fi

exit 0
