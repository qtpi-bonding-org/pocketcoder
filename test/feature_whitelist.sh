#!/bin/bash
# test/feature_whitelist.sh
# Tests Phase 3: Whitelist Rules Persistence

POCKETBASE_URL="http://127.0.0.1:8090"

# Load from .env
if [ -f .env ]; then
    ADMIN_EMAIL=$(grep "^POCKETBASE_SUPERUSER_EMAIL=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
    ADMIN_PASS=$(grep "^POCKETBASE_SUPERUSER_PASSWORD=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
else
    echo "❌ .env file not found."
    exit 1
fi

echo "🔐 [Whitelist] Authenticating..."
AUTH_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$ADMIN_EMAIL\", \"password\":\"$ADMIN_PASS\"}")
ADMIN_TOKEN=$(echo $AUTH_RES | jq -r '.token')

# 1. Create Target
echo "🎯 Creating Whitelist Target..."
TARGET_ID=$(curl -s -X POST "$POCKETBASE_URL/api/collections/whitelist_targets/records" \
    -H "Authorization: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"PH3 Test Target\", \"pattern\":\"github.com/pocketcoder/*\", \"type\":\"repo\"}" | jq -r '.id')
echo "✅ Target ID: $TARGET_ID"

# 2. Create Action
echo "⚡ Creating Whitelist Action..."
ACTION_ID=$(curl -s -X POST "$POCKETBASE_URL/api/collections/whitelist_actions/records" \
    -H "Authorization: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"command\":\"git clone\", \"target\":\"$TARGET_ID\", \"is_active\": true}" | jq -r '.id')
echo "✅ Action ID: $ACTION_ID"

# 3. Verify Retrieval
echo "🔍 Verifying Action Data..."
ACTION_DETAIL=$(curl -s "$POCKETBASE_URL/api/collections/whitelist_actions/records/$ACTION_ID?expand=target" \
    -H "Authorization: $ADMIN_TOKEN")

COMMAND=$(echo $ACTION_DETAIL | jq -r '.command')
PATTERN=$(echo $ACTION_DETAIL | jq -r '.expand.target.pattern')

if [[ "$COMMAND" == "git clone" ]] && [[ "$PATTERN" == "github.com/pocketcoder/*" ]]; then
    echo "✅ Whitelist Persistence Working."
else
    echo "❌ Whitelist Verification Failed."
    echo "Response: $ACTION_DETAIL"
    exit 1
fi

echo "🏁 WHITELIST FEATURE TEST PASSED!"
