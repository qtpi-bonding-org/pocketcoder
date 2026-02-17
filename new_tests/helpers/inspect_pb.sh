#!/bin/bash
# new_tests/helpers/inspect_pb.sh
# Queries PocketBase collections and formats output with jq highlighting relevant fields.
# Usage: ./helpers/inspect_pb.sh [chats|messages|subagents|permissions]

set -e

# Load .env and get token
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

PB_URL="${POCKETBASE_URL:-http://127.0.0.1:8090}"
COLLECTION=$1

if [ -z "$COLLECTION" ]; then
    echo "Usage: $0 [chats|messages|subagents|permissions]"
    exit 1
fi

# Get admin token
TOKEN_RES=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{
        \"identity\": \"$POCKETBASE_ADMIN_EMAIL\",
        \"password\": \"$POCKETBASE_ADMIN_PASSWORD\"
    }")

TOKEN=$(echo "$TOKEN_RES" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "❌ Failed to retrieve admin token" >&2
    exit 1
fi

echo "🔍 PocketBase Collection: $COLLECTION"
echo "--------------------------------------------------------------------------------"

case $COLLECTION in
    "chats")
        curl -s -X GET "$PB_URL/api/collections/chats/records" \
            -H "Authorization: $TOKEN" \
            | jq '.items[] | {id, agent_id, title, user, agent, turn, last_active, preview}'
        ;;
    "messages")
        curl -s -X GET "$PB_URL/api/collections/messages/records" \
            -H "Authorization: $TOKEN" \
            | jq '.items[] | {id, chat, agent_message_id, role, parts, delivery}'
        ;;
    "subagents")
        curl -s -X GET "$PB_URL/api/collections/subagents/records" \
            -H "Authorization: $TOKEN" \
            | jq '.items[] | {id, subagent_id, delegating_agent_id, tmux_window_id}'
        ;;
    "permissions")
        curl -s -X GET "$PB_URL/api/collections/permissions/records" \
            -H "Authorization: $TOKEN" \
            | jq '.items[] | {id, chat, agent_permission_id, status, command}'
        ;;
    *)
        echo "Unknown collection: $COLLECTION"
        echo "Valid options: chats, messages, subagents, permissions"
        exit 1
        ;;
esac

echo "--------------------------------------------------------------------------------"