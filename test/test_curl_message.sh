#!/bin/bash
# 🧪 PocketCoder Chat Loop Tester
# This script sends a message to PocketBase as the Admin user to trigger the relay -> OpenCode loop.

POCKETBASE_URL="http://127.0.0.1:8090"

# Load from .env
if [ -f .env ]; then
    USER_EMAIL=$(grep "^POCKETBASE_USER_EMAIL=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
    USER_PASS=$(grep "^POCKETBASE_USER_PASSWORD=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
else
    echo "❌ .env file not found. Run bash genesis.sh first."
    exit 1
fi

if [ -z "$USER_EMAIL" ] || [ -z "$USER_PASS" ]; then
    echo "❌ Credentials not found in .env"
    exit 1
fi

echo "🔐 Authenticating as User: $USER_EMAIL..."
AUTH_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$USER_EMAIL\", \"password\":\"$USER_PASS\"}")

USER_TOKEN=$(echo $AUTH_RES | grep -o '"token":"[^"]*' | cut -d'"' -f4)
USER_ID=$(echo $AUTH_RES | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -z "$USER_TOKEN" ]; then
    echo "❌ Auth Failed"
    echo $AUTH_RES
    exit 1
fi

echo "✅ Authenticated. User ID: $USER_ID"

# 1. Ensure Chat
echo "📁 Finding/Creating Chat..."
CHAT_LIST=$(curl -s "$POCKETBASE_URL/api/collections/chats/records?filter=user='$USER_ID'" \
    -H "Authorization: Bearer $USER_TOKEN")

CHAT_ID=$(echo $CHAT_LIST | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4)

if [ -z "$CHAT_ID" ]; then
    # Create if not found
    CHAT_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/chats/records" \
        -H "Authorization: Bearer $USER_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"CURL Test\", \"user\":\"$USER_ID\"}")
    CHAT_ID=$(echo $CHAT_RES | grep -o '"id":"[^"]*' | cut -d'"' -f4)
fi

if [ -z "$CHAT_ID" ]; then
    echo "❌ Failed to find or create a chat."
    exit 1
fi

echo "✅ Using Chat ID: $CHAT_ID"

# 2. Send Message
echo "📨 Sending Message..."
MSG_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/messages/records" \
    -H "Authorization: Bearer $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"content\": \"Hello! Please list the files in the current directory.\"}]
    }")

MSG_ID=$(echo $MSG_RES | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -z "$MSG_ID" ]; then
    echo "❌ Failed to send message."
    echo $MSG_RES
    exit 1
fi

echo "🚀 Message Sent (ID: $MSG_ID). Waiting for Bridge -> OpenCode..."
