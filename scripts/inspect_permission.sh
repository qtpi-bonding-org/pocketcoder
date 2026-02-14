#!/bin/bash
# inspect_permission.sh
set -e

if [ ! -f .env ]; then
    echo "❌ Error: .env file not found"
    exit 1
fi

export $(grep -v '^#' .env | xargs)
PB_URL="http://127.0.0.1:8090"

# 1. Authenticate as Admin
echo "🔑 Authenticating as Admin..."
AUTH_RES=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{
        \"identity\": \"$POCKETBASE_ADMIN_EMAIL\",
        \"password\": \"$POCKETBASE_ADMIN_PASSWORD\"
    }")

USER_TOKEN=$(echo "$AUTH_RES" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$USER_TOKEN" ]; then
    echo "❌ Authentication failed!"
    exit 1
fi

# 2. Get the latest permission request
echo "🔍 Fetching latest permission request..."
PERMS_RES=$(curl -s -X GET "$PB_URL/api/collections/permissions/records?sort=-created&perPage=1" \
    -H "Authorization: $USER_TOKEN")

echo "📋 Latest Permission Request JSON:"
echo "$PERMS_RES"
