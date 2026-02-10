#!/bin/bash
# test/feature_identity_check.sh
# Verifies that Poco knows its name and isn't just echoing.

set -e

# 1. Load .env
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found in root directory."
    exit 1
fi

echo "📂 Loading configuration from .env..."
export $(grep -v '^#' .env | xargs)

PB_URL="http://127.0.0.1:8090"

# 2. Authenticate as User
echo "🔑 Logging into PocketBase as Human ($POCKETBASE_USER_EMAIL)..."
AUTH_RES=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{
        \"identity\": \"$POCKETBASE_USER_EMAIL\",
        \"password\": \"$POCKETBASE_USER_PASSWORD\"
    }")

USER_TOKEN=$(echo "$AUTH_RES" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
USER_ID=$(echo "$AUTH_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)

if [ -z "$USER_TOKEN" ]; then
    echo "❌ Authentication failed!"
    exit 1
fi

# 3. Create a Chat
echo "💬 Creating a new Chat..."
CHAT_RES=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"user\": \"$USER_ID\",
        \"title\": \"Identity Check $(date +%H:%M:%S)\"
    }")

CHAT_ID=$(echo "$CHAT_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -n 1)

# 4. Send "What is your name?"
echo "📩 Sending 'what is your name?' to Poco..."
curl -s -X POST "$PB_URL/api/collections/messages/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [
            { \"type\": \"text\", \"text\": \"what is your name?\" }
        ],
        \"metadata\": { \"processed\": false }
    }" > /dev/null

echo "⏳ Waiting for response..."
FOUND_POCO=false
for i in {1..15}; do
    echo "🔍 Checking for assistant response... (Attempt $i/15)"
    MESSAGES_RES=$(curl -s -X GET "$PB_URL/api/collections/messages/records?filter=(chat%3D%27$CHAT_ID%27%20%26%26%20role%3D%27assistant%27)" \
        -H "Authorization: $USER_TOKEN")
    
    # Check if "Poco" exists in the JSON response
    if echo "$MESSAGES_RES" | grep -qi "Poco"; then
        echo "🎉 SUCCESS! Poco identified itself."
        FOUND_POCO=true
        break
    fi
    
    # Also check if it's echoing (to provide better error if it fails)
    if echo "$MESSAGES_RES" | grep -q '{"text":"what is your name?"'; then
        echo "❌ FAILURE: Detected echo in assistant message. The AI is just repeating the prompt."
        echo "$MESSAGES_RES" | jq .
        exit 1
    fi

    sleep 2
done

if [ "$FOUND_POCO" = false ]; then
    echo "❌ FAILURE: Poco did not identify itself. Assistant response follows:"
    echo "$MESSAGES_RES" | jq .
    exit 1
fi
