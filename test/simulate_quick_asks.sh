#!/bin/bash
# test/simulate_quick_asks.sh
set -e
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
PB_URL="http://127.0.0.1:8090"
USER_TOKEN=$("$SCRIPTS_DIR/get_token.sh" user)
USER_ID=$(echo "$USER_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

CHAT_RES=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"user\": \"$USER_ID\", \"title\": \"Quick Fire Test\"}")
CHAT_ID=$(echo "$CHAT_RES" | jq -r .id)

echo "🔥 Sending two messages instantly..."
curl -s -X POST "$PB_URL/api/collections/messages/records" -H "Authorization: $USER_TOKEN" -H "Content-Type: application/json" -d "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"First message\"}], \"delivery\": \"pending\"}" &
curl -s -X POST "$PB_URL/api/collections/messages/records" -H "Authorization: $USER_TOKEN" -H "Content-Type: application/json" -d "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Second message\"}], \"delivery\": \"pending\"}" &

wait
echo "⏳ Waiting for PBP logs to show syncs..."
sleep 10

echo "🔍 Checking messages in Chat $CHAT_ID..."
curl -s -X GET "$PB_URL/api/collections/messages/records?filter=(chat%3D%27$CHAT_ID%27)&sort=created" -H "Authorization: $USER_TOKEN" | jq '.items[] | {role, text: .parts[].text}'
