#!/bin/bash
# backend/tests/relay_health_check.sh
# End-to-end relay validation

set -e

POCKETBASE_URL="http://127.0.0.1:8090"
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_NC='\033[0m'

echo "🧪 [Health Check] Initializing Relay End-to-End Test..."

# 1. Load Credentials
if [ -f .env ]; then
    USER_EMAIL=$(grep "^POCKETBASE_USER_EMAIL=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
    USER_PASS=$(grep "^POCKETBASE_USER_PASSWORD=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
else
    echo -e "${C_RED}❌ .env file not found.${C_NC}"
    exit 1
fi

# 2. Authenticate
echo "🔐 Authenticating as $USER_EMAIL..."
AUTH_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$USER_EMAIL\", \"password\":\"$USER_PASS\"}")

USER_TOKEN=$(echo $AUTH_RES | grep -o '"token":"[^"]*' | cut -d'"' -f4)
USER_ID=$(echo $AUTH_RES | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -z "$USER_TOKEN" ]; then
    echo -e "${C_RED}❌ Auth Failed${C_NC}"
    exit 1
fi
echo -e "${C_GREEN}✅ Authenticated (ID: $USER_ID)${C_NC}"

# 3. Find/Create Chat
echo "📁 Resolving Chat Context..."
CHAT_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/chats/records" \
    -H "Authorization: Bearer $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"Relay Test $(date +%s)\", \"user\":\"$USER_ID\"}")
CHAT_ID=$(echo $CHAT_RES | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -z "$CHAT_ID" ]; then
    echo -e "${C_RED}❌ Chat Creation Failed${C_NC}"
    exit 1
fi
echo -e "${C_GREEN}✅ Chat Ready: $CHAT_ID${C_NC}"

# 4. Post Message
echo "📨 Sending 'echo' message..."
MSG_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/messages/records" \
    -H "Authorization: Bearer $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"text\": \"ping\"}]
    }")
MSG_ID=$(echo $MSG_RES | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -z "$MSG_ID" ]; then
    echo -e "${C_RED}❌ Message Posting Failed${C_NC}"
    exit 1
fi
echo -e "${C_GREEN}✅ Message $MSG_ID is live.${C_NC}"

# 5. Wait and Verify Processed
echo "⏳ Waiting for Relay to process (5s)..."
sleep 5

VERIFY_RES=$(curl -s "$POCKETBASE_URL/api/collections/messages/records/$MSG_ID" \
    -H "Authorization: Bearer $USER_TOKEN")
PROCESSED=$(echo $VERIFY_RES | grep -o '"processed":true')

if [ -z "$PROCESSED" ]; then
    echo -e "${C_RED}❌ FAILED: Relay did not mark message as processed.${C_NC}"
    echo "Check PocketBase logs: docker-compose logs pocketbase"
    exit 1
fi
echo -e "${C_GREEN}✅ Relay intercepted and processed the message.${C_NC}"

# 6. Check for Assistant Response
echo "⏳ Waiting for Assistant response (15s)..."
sleep 15

RESP_RES=$(curl -s "$POCKETBASE_URL/api/collections/messages/records?filter=(chat='$CHAT_ID'+%26%26+role='assistant')" \
    -H "Authorization: Bearer $USER_TOKEN")
ASSISTANT_MSG=$(echo $RESP_RES | grep -o '"role":"assistant"')

if [ -z "$ASSISTANT_MSG" ]; then
    echo -e "${C_RED}❌ FAILED: No assistant response found.${C_NC}"
    exit 1
fi

echo -e "${C_GREEN}🎉 SUCCESS: Relay loop is fully operational!${C_NC}"
