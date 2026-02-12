#!/bin/bash
# scripts/get_token.sh
# Utility to retrieve JWT tokens for different roles in PocketCoder.
# Usage: ./scripts/get_token.sh [superuser|user|agent]

set -e

ROLE=$1
PB_URL="http://127.0.0.1:8090"

# Load .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

case $ROLE in
    "superuser")
        IDENTITY=$POCKETBASE_SUPERUSER_EMAIL
        PASSWORD=$POCKETBASE_SUPERUSER_PASSWORD
        COLLECTION="_superusers"
        ;;
    "user")
        IDENTITY=$POCKETBASE_ADMIN_EMAIL
        PASSWORD=$POCKETBASE_ADMIN_PASSWORD
        COLLECTION="users"
        ;;
    "agent")
        IDENTITY=$AGENT_EMAIL
        PASSWORD=$AGENT_PASSWORD
        COLLECTION="users"
        ;;
    *)
        echo "Usage: $0 [superuser|user|agent]"
        exit 1
        ;;
esac

TOKEN_RES=$(curl -s -X POST "$PB_URL/api/collections/$COLLECTION/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{
        \"identity\": \"$IDENTITY\",
        \"password\": \"$PASSWORD\"
    }")

TOKEN=$(echo "$TOKEN_RES" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "❌ Failed to retrieve token for $ROLE" >&2
    echo "$TOKEN_RES" >&2
    exit 1
fi

echo "$TOKEN"
