#!/bin/bash
# test/auto_approve.sh
# Polls and automatically approves any 'draft' permissions in the most recent chat.

set -e

# 1. Load .env
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found in root directory."
    exit 1
fi

export $(grep -v '^#' .env | xargs)
PB_URL="http://127.0.0.1:8090"

# 2. Authenticate as User
echo "🔑 Logging into PocketBase..."
AUTH_RES=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{
        \"identity\": \"$POCKETBASE_ADMIN_EMAIL\",
        \"password\": \"$POCKETBASE_ADMIN_PASSWORD\"
    }")

USER_TOKEN=$(echo "$AUTH_RES" | jq -r '.token')
if [ -z "$USER_TOKEN" ] || [ "$USER_TOKEN" == "null" ]; then
    echo "❌ Authentication failed!"
    exit 1
fi

echo "🛡️  Auto-Approver Active. Watching for DRAFT permissions..."

while true; do
    # Find all draft permissions
    PERMS_RES=$(curl -s -X GET "$PB_URL/api/collections/permissions/records?filter=(status='draft')" \
        -H "Authorization: $USER_TOKEN")
    
    # Get IDs of all drafts
    IDS=$(echo "$PERMS_RES" | jq -r '.items[].id')
    
    for ID in $IDS; do
        if [ "$ID" != "null" ]; then
            echo "🔓 Authorizing permission: $ID"
            curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$ID" \
                -H "Authorization: $USER_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{ \"status\": \"authorized\" }" > /dev/null
            echo "✅ Approved."
        fi
    done
    
    sleep 3
done
