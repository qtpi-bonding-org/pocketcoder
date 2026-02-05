#!/bin/bash
set -e

# Load .env variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# API URL
API_URL="http://127.0.0.1:8090"
# Use env vars or fallbacks
AGENT_EMAIL="${AGENT_EMAIL:-agent@pocketcoder.io}"
AGENT_PASS="${AGENT_PASSWORD:-password123}"

echo "🧪 [Stream Test] Starting Ephemeral Stream Verification..."

# 1. Get Agent Token
echo "🔑 Authenticating as Agent..."
AGENT_TOKEN=$(curl -s -X POST "$API_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$AGENT_EMAIL\",\"password\":\"$AGENT_PASS\"}" | jq -r '.token')

if [ -z "$AGENT_TOKEN" ] || [ "$AGENT_TOKEN" == "null" ]; then
    echo "❌ Failed to get Agent token"
    exit 1
fi
echo "✅ Agent Authenticated"

# 2. Test Stream Publishing (Success Case)
echo "📡 Testing Log Broadcast (Valid Agent)..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/api/pocketcoder/stream" \
    -H "Authorization: $AGENT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"topic":"logs", "data":{"text":"Hello World"}}')

if [ "$STATUS" == "200" ]; then
    echo "✅ Broadcast Successful (200 OK)"
else
    echo "❌ Broadcast Failed (Status: $STATUS)"
    exit 1
fi

# 3. Test Stream Publishing (Failure Case - No Auth)
echo "🔒 Testing unauthorized broadcast..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/api/pocketcoder/stream" \
    -H "Content-Type: application/json" \
    -d '{"topic":"logs", "data":{"text":"HACKER"}}')

if [ "$STATUS" == "403" ]; then
    echo "✅ Unauthorized access blocked (403 Forbidden)"
else
    echo "❌ Unexpected status for unauthorized access: $STATUS"
    exit 1
fi


echo "🎉 Stream Test Passed!"
