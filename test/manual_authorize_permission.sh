#!/bin/bash
# test/manual_authorize_permission.sh
# Manually authorize a specific permission by its OpenCode ID

PB_URL="http://127.0.0.1:8090"

# Load credentials from .env
if [ -f .env ]; then
    EMAIL=$(grep "^POCKETBASE_USER_EMAIL=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
    PASS=$(grep "^POCKETBASE_USER_PASSWORD=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
else
    echo "❌ .env file not found"
    exit 1
fi

# Get OpenCode permission ID from argument
if [ -z "$1" ]; then
    echo "Usage: $0 <opencode_permission_id>"
    echo "Example: $0 per_c3fb4b4a6001dCaXWsLCHsxwKd"
    exit 1
fi

OPENCODE_PERM_ID="$1"

echo "1. Authenticating..."
TOKEN=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"$EMAIL\",\"password\":\"$PASS\"}" | jq -r '.token')

if [ "$TOKEN" == "null" ]; then
    echo "❌ Authentication failed"
    exit 1
fi
echo "✅ Authenticated"

echo "2. Finding Permission Record..."
RECORD=$(curl -s -G "$PB_URL/api/collections/permissions/records" \
  --data-urlencode "filter=opencode_id='$OPENCODE_PERM_ID'" \
  -H "Authorization: $TOKEN")

RECORD_ID=$(echo "$RECORD" | jq -r '.items[0].id')

if [ "$RECORD_ID" == "null" ]; then
    echo "❌ Permission record not found for OpenCode ID: $OPENCODE_PERM_ID"
    exit 1
fi
echo "✅ Found Record ID: $RECORD_ID"

echo "3. Authorizing..."
UPDATE=$(curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$RECORD_ID" \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "authorized"}')

echo "✅ Updated. Relay should pick this up and notify OpenCode."
