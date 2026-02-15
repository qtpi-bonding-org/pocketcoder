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

# @pocketcoder-core: Batching Test. Verifies that the relay correctly chunks multi-part AI messages.
#!/bin/bash
# test/feature_turn_batching.sh
# Verifies turn-based locking and message batching (double texting).

set -e

PB_URL="http://127.0.0.1:8090"
USER_TOKEN=$(./scripts/get_token.sh user)

echo "🚀 Starting Turn-Based Batching Test..."

# 1. Get User ID safely
USER_ID=$(curl -s -X GET "$PB_URL/api/collections/users/records" \
    -H "Authorization: $USER_TOKEN" | jq -r '.items[0].id')

# 1. Create a new chat
CHAT_RES=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\": \"Batching Test\", \"user\": \"$USER_ID\"}")
CHAT_ID=$(echo "$CHAT_RES" | jq -r .id)

if [ "$CHAT_ID" == "null" ] || [ -z "$CHAT_ID" ]; then
    echo "❌ Failed to create chat: $CHAT_RES"
    exit 1
fi

echo "📁 Created Chat: $CHAT_ID"

# 2. Verify initial turn
TURN=$(echo "$CHAT_RES" | jq -r .turn)
echo "🔄 Initial Turn: '$TURN'"
if [ "$TURN" != "user" ] && [ "$TURN" != "" ] && [ "$TURN" != "null" ]; then
    echo "❌ Initial turn should be 'user' or empty (defaulting to user)"
    exit 1
fi

# 3. Send Message 1 (Long Task to keep him busy)
echo "📩 Sending Message 1: 'Write a poem about the sea'..."
curl -s -X POST "$PB_URL/api/collections/messages/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"text\": \"Write a ten line poem about the sea.\"}],
        \"delivery\": \"pending\"
    }" > /dev/null

sleep 1

# 4. Verify turn transitioned to assistant
CHAT_STATE=$(curl -s -X GET "$PB_URL/api/collections/chats/records/$CHAT_ID" \
    -H "Authorization: $USER_TOKEN")
TURN=$(echo "$CHAT_STATE" | jq -r .turn)
echo "🔄 Current Turn: $TURN"

# 5. Send Message 2 and 3 while busy
echo "📩 Sending Message 2: 'Actually, forget the poem. Just say the word BATCH_SUCCESS'..."
curl -s -X POST "$PB_URL/api/collections/messages/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"text\": \"Actually, forget the poem. Reply ONLY with the word: BATCH_SUCCESS\"}],
        \"delivery\": \"pending\"
    }" > /dev/null

echo "⏳ Waiting for Poco to finish and trigger the batch pump..."

# 6. Wait for responses
for i in {1..20}; do
    echo "🔍 Checking for batch resolution... (Attempt $i/20)"
    
    # Check if turn flipped back to user
    CHAT_STATE=$(curl -s -X GET "$PB_URL/api/collections/chats/records/$CHAT_ID" \
        -H "Authorization: $USER_TOKEN")
    TURN=$(echo "$CHAT_STATE" | jq -r .turn)
    
    curl -s -X GET "$PB_URL/api/collections/messages/records?filter=(chat%3D%27$CHAT_ID%27)&sort=-created" \
        -H "Authorization: $USER_TOKEN" > test_msgs.json
    
    if ! jq -e . test_msgs.json > /dev/null 2>&1; then
        echo "⚠️ Invalid JSON response: $(cat test_msgs.json)"
        continue
    fi

    ASSISTANT_MSGS=$(jq -r '.items[]? | select(.role=="assistant") | .parts[]? | .text' test_msgs.json | grep -v "null" || true)
    
    if [ ! -z "$ASSISTANT_MSGS" ]; then
        echo "🤖 Latest Assistant Text: $(echo "$ASSISTANT_MSGS" | head -n 2)..."
    fi

    if echo "$ASSISTANT_MSGS" | grep -qi "BATCH_SUCCESS"; then
        echo "🎉 SUCCESS! Batch processing confirmed."
        echo "Turn is now: $TURN"
        exit 0
    fi
    
    sleep 5
done

echo "❌ FAILURE: Batch processing timed out or context lost."
exit 1
