#!/bin/bash
# test/feature_identity_check.sh
# Verifies that Poco knows its name and is correctly triggered.

set -e

# 1. Load configuration and helper
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
PB_URL="http://127.0.0.1:8090"

if [ ! -f "$SCRIPTS_DIR/get_token.sh" ]; then
    echo "❌ Error: scripts/get_token.sh not found."
    exit 1
fi

# 2. Get User Token
echo "🔑 Retrieving User Token..."
USER_TOKEN=$("$SCRIPTS_DIR/get_token.sh" user)

if [ -z "$USER_TOKEN" ]; then
    echo "❌ Failed to get user token."
    exit 1
fi

# Get User ID from token (base64 decode)
USER_ID=$(echo "$USER_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

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
echo "✅ Chat Created: $CHAT_ID"

# 4. Send "what is your name?"
PROMPT="what is your name?"
echo "📩 Sending '$PROMPT'..."
curl -s -X POST "$PB_URL/api/collections/messages/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [
            { \"type\": \"text\", \"text\": \"$PROMPT\" }
        ],
        \"metadata\": { \"processed\": false }
    }" > /dev/null

echo "⏳ Waiting for response..."
FOUND_POCO=false

for i in {1..15}; do
    echo "🔍 Checking for response... (Attempt $i/15)"
    MESSAGES_RES=$(curl -s -X GET "$PB_URL/api/collections/messages/records?filter=(chat%3D%27$CHAT_ID%27)" \
        -H "Authorization: $USER_TOKEN")
    
    # Extract only assistant messages
    ASSISTANT_TEXT=$(echo "$MESSAGES_RES" | jq -r '.items[] | select(.role=="assistant") | .parts[].text' | grep -v "null" | grep -v "$PROMPT" || true)
    
    if echo "$ASSISTANT_TEXT" | grep -qi "Poco"; then
        echo "🎉 SUCCESS! Poco identified itself."
        echo "Response: $ASSISTANT_TEXT"
        FOUND_POCO=true
        break
    fi
    
    # Check for echo failure specifically
    if echo "$ASSISTANT_TEXT" | grep -qF "$PROMPT"; then
        echo "❌ FAILURE: Detected echo. The AI just repeated the prompt."
        exit 1
    fi

    sleep 2
done

if [ "$FOUND_POCO" = false ]; then
    echo "❌ FAILURE: Poco did not identify itself."
    echo "Last assistant responses:"
    echo "$ASSISTANT_TEXT"
    exit 1
fi
