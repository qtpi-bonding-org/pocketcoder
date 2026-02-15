# PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
# Copyright (C) 2026 Qtpi Bonding LLC
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


# @pocketcoder-core: Artifact Test. Validates the secure serving of feature artifacts to the reasoning engine.
#!/bin/bash
# test/feature_artifacts.sh
# Tests Phase 2: Artifact Serving API

POCKETBASE_URL="http://127.0.0.1:8090"
TEST_FILE="artifact_test_$(date +%s).txt"
TEST_CONTENT="Artifact content for feature test"

# Load from .env
if [ -f .env ]; then
    SUPERUSER_EMAIL=$(grep "^POCKETBASE_SUPERUSER_EMAIL=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
    SUPERUSER_PASS=$(grep "^POCKETBASE_SUPERUSER_PASSWORD=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
else
    echo "❌ .env file not found."
    exit 1
fi

echo "🔐 [Artifacts] Authenticating as Superuser..."
AUTH_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$SUPERUSER_EMAIL\", \"password\":\"$SUPERUSER_PASS\"}")
SUPERUSER_TOKEN=$(echo $AUTH_RES | jq -r '.token')

echo "📁 [Artifacts] Creating test file in workspace..."
docker exec pocketcoder-sandbox sh -c "echo '$TEST_CONTENT' > /workspace/$TEST_FILE"

echo "🔍 Fetching artifact via API..."
# Endpoint: /api/pocketcoder/artifact/{path...}
URL="$POCKETBASE_URL/api/pocketcoder/artifact/$TEST_FILE"
RESPONSE=$(curl -s -H "Authorization: $SUPERUSER_TOKEN" "$URL")

if [[ "$RESPONSE" == "$TEST_CONTENT" ]]; then
    echo "✅ Artifact Serving Working."
else
    echo "❌ Artifact Serving Failed."
    echo "   Expected: $TEST_CONTENT"
    echo "   Received: $RESPONSE"
    exit 1
fi

echo "🏁 ARTIFACTS FEATURE TEST PASSED!"
