#!/bin/bash
# scripts/cleanup_and_reseed.sh
set -e

POCKETBASE_URL="http://127.0.0.1:8090"

# Load from .env
if [ -f .env ]; then
    ADMIN_EMAIL=$(grep "^POCKETBASE_SUPERUSER_EMAIL=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
    ADMIN_PASS=$(grep "^POCKETBASE_SUPERUSER_PASSWORD=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
else
    echo "❌ .env file not found."
    exit 1
fi

AUTH_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$ADMIN_EMAIL\", \"password\":\"$ADMIN_PASS\"}")
TOKEN=$(echo $AUTH_RES | jq -r '.token')

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
    echo "❌ Admin Auth Failed"
    exit 1
fi

echo "🔐 Authenticated."

# Delete all ai_agents
IDS=$(curl -s "$POCKETBASE_URL/api/collections/ai_agents/records" -H "Authorization: $TOKEN" | jq -r '.items[].id')
for ID in $IDS; do
    echo "🗑️ Deleting Agent: $ID"
    curl -s -X DELETE "$POCKETBASE_URL/api/collections/ai_agents/records/$ID" -H "Authorization: $TOKEN"
done

# Delete all ai_prompts
IDS=$(curl -s "$POCKETBASE_URL/api/collections/ai_prompts/records" -H "Authorization: $TOKEN" | jq -r '.items[].id')
for ID in $IDS; do
    echo "🗑️ Deleting Prompt: $ID"
    curl -s -X DELETE "$POCKETBASE_URL/api/collections/ai_prompts/records/$ID" -H "Authorization: $TOKEN"
done

# Delete all ai_models
IDS=$(curl -s "$POCKETBASE_URL/api/collections/ai_models/records" -H "Authorization: $TOKEN" | jq -r '.items[].id')
for ID in $IDS; do
    echo "🗑️ Deleting Model: $ID"
    curl -s -X DELETE "$POCKETBASE_URL/api/collections/ai_models/records/$ID" -H "Authorization: $TOKEN"
done

echo "📝 Seeding Poco..."

# 1. Create Default Poco Prompt
PROMPT_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ai_prompts/records" \
    -H "Authorization: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\": \"Poco Core\",
        \"body\": \"You are Poco, the primary AI Orchestrator for PocketCoder. Your goal is to help the user build high-quality software by coordinating tasks, managing the sandbox, and ensuring architectural integrity. You are thoughtful, Socratic, and always check for consent before making destructive changes.\"
    }")
PROMPT_ID=$(echo $PROMPT_RES | jq -r '.id')

# 2. Create Gemini Flash Model
MODEL_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ai_models/records" \
    -H "Authorization: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\": \"Gemini Flash\",
        \"identifier\": \"google/gemini-2.0-flash-exp\"
    }")
MODEL_ID=$(echo $MODEL_RES | jq -r '.id')

# 3. Create Poco Agent
AGENT_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ai_agents/records" \
    -H "Authorization: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\": \"poco\",
        \"is_init\": true,
        \"mode\": \"primary\",
        \"prompt\": \"$PROMPT_ID\",
        \"model\": \"$MODEL_ID\"
    }")
AGENT_ID=$(echo $AGENT_RES | jq -r '.id')

echo "✅ Poco Seeded: $AGENT_ID"

# 4. Link existing chats
CHAT_IDS=$(curl -s "$POCKETBASE_URL/api/collections/chats/records" -H "Authorization: $TOKEN" | jq -r '.items[].id')
for CHAT_ID in $CHAT_IDS; do
    echo "🔗 Linking Chat $CHAT_ID to Poco..."
    curl -s -X PATCH "$POCKETBASE_URL/api/collections/chats/records/$CHAT_ID" \
        -H "Authorization: $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"agent\": \"$AGENT_ID\"}"
done

echo "✨ Seed Complete."
