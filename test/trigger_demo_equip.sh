#!/bin/bash
# test/trigger_demo_equip.sh
# Automates the trigger of the Terraform subagent setup by sending a message to Poco via PocketBase.

set -e

# 1. Load .env
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found in root directory."
    exit 1
fi

echo "📂 Loading configuration from .env..."
export $(grep -v '^#' .env | xargs)

# Note: Using localhost because this script runs on the host machine
PB_URL="http://127.0.0.1:8090"

# 2. Authenticate as User
echo "🔑 Logging into PocketBase as Human ($POCKETBASE_ADMIN_EMAIL)..."
AUTH_RES=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{
        \"identity\": \"$POCKETBASE_ADMIN_EMAIL\",
        \"password\": \"$POCKETBASE_ADMIN_PASSWORD\"
    }")

USER_TOKEN=$(echo "$AUTH_RES" | jq -r '.token')
USER_ID=$(echo "$AUTH_RES" | jq -r '.record.id')

if [ -z "$USER_TOKEN" ] || [ "$USER_TOKEN" == "null" ]; then
    echo "❌ Authentication failed!"
    echo "$AUTH_RES"
    exit 1
fi
echo "✅ Logged in. Token retrieved."

# 3. Create a Chat
echo "💬 Creating a new Chat for Terraform Setup..."
CHAT_RES=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"user\": \"$USER_ID\",
        \"title\": \"Linode Migration Preparation\"
    }")

CHAT_ID=$(echo "$CHAT_RES" | jq -r '.id')
echo "✅ Chat Created: $CHAT_ID"

# 4. Trigger Poco
PROMPT="Poco, please apply the 'architect' skill workflow to provision the Terraform MCP server in the sandbox, set up a 'terraform_expert' subagent, and then have that subagent search the registry for the Linode provider."

echo "📩 Sending prompt to Poco..."
MSG_RES=$(curl -s -X POST "$PB_URL/api/collections/messages/records" \
    -H "Authorization: $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [
            { \"type\": \"text\", \"text\": \"$PROMPT\" }
        ],
        \"delivery\": \"pending\"
    }")

echo "✅ Message sent. PocketCoder (Poco) should be picking this up now."
echo "🔗 Watch the logs for 'Permission Requests' (Drafts) that require your signature!"
echo ""
echo "Command to follow logs:"
echo "docker compose logs -f relay opencode"
