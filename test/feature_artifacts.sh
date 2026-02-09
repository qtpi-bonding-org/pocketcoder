#!/bin/bash
# test/feature_artifacts.sh
# Tests Phase 2: Artifact Serving API

POCKETBASE_URL="http://127.0.0.1:8090"
TEST_FILE="artifact_test_$(date +%s).txt"
TEST_CONTENT="Artifact content for feature test"

# Load from .env
if [ -f .env ]; then
    ADMIN_EMAIL=$(grep "^POCKETBASE_SUPERUSER_EMAIL=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
    ADMIN_PASS=$(grep "^POCKETBASE_SUPERUSER_PASSWORD=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
else
    echo "❌ .env file not found."
    exit 1
fi

echo "🔐 [Artifacts] Authenticating..."
AUTH_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$ADMIN_EMAIL\", \"password\":\"$ADMIN_PASS\"}")
ADMIN_TOKEN=$(echo $AUTH_RES | jq -r '.token')

echo "📁 [Artifacts] Creating test file in workspace..."
docker exec pocketcoder-opencode sh -c "echo '$TEST_CONTENT' > /workspace/$TEST_FILE"

echo "🔍 Fetching artifact via API..."
# Endpoint: /api/openclaw/artifact/{path...}
URL="$POCKETBASE_URL/api/openclaw/artifact/$TEST_FILE"
RESPONSE=$(curl -s -H "Authorization: $ADMIN_TOKEN" "$URL")

if [[ "$RESPONSE" == "$TEST_CONTENT" ]]; then
    echo "✅ Artifact Serving Working."
else
    echo "❌ Artifact Serving Failed."
    echo "   Expected: $TEST_CONTENT"
    echo "   Received: $RESPONSE"
    exit 1
fi

echo "🏁 ARTIFACTS FEATURE TEST PASSED!"
