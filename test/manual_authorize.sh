#!/bin/bash
PB_URL="http://127.0.0.1:8090"
EMAIL="agent@pocketcoder.local"
PASS="EJ6IiRKdHR8Do6IogD7PApyErxDZhUmp"
OPENCODE_perm_ID="per_c3fb4b4a6001dCaXWsLCHsxwKd" # From previous log

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
  --data-urlencode "filter=opencode_id='$OPENCODE_perm_ID'" \
  -H "Authorization: $TOKEN")

RECORD_ID=$(echo "$RECORD" | jq -r '.items[0].id')

if [ "$RECORD_ID" == "null" ]; then
    echo "❌ Permission record not found for OpenCode ID: $OPENCODE_perm_ID"
    # echo "Response: $RECORD"
    exit 1
fi
echo "✅ Found Record ID: $RECORD_ID"

echo "3. Authorizing..."
UPDATE=$(curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$RECORD_ID" \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "authorized"}')

echo "✅ Updated. Bridge should pick this up."
