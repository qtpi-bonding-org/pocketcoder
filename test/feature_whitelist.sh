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


# @pocketcoder-core: Whitelist Test. Confirms that automatic rules correctly authorize low-risk commands.
#!/bin/bash
# test/feature_whitelist.sh
# Tests Phase 3: Whitelist Rules Persistence

POCKETBASE_URL="http://127.0.0.1:8090"

# Load from .env
if [ -f .env ]; then
    SUPERUSER_EMAIL=$(grep "^POCKETBASE_SUPERUSER_EMAIL=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
    SUPERUSER_PASS=$(grep "^POCKETBASE_SUPERUSER_PASSWORD=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
else
    echo "❌ .env file not found."
    exit 1
fi

echo "🔐 [Whitelist] Authenticating as Superuser..."
AUTH_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$SUPERUSER_EMAIL\", \"password\":\"$SUPERUSER_PASS\"}")
SUPERUSER_TOKEN=$(echo $AUTH_RES | jq -r '.token')

# 1. Create Target
echo "🎯 Creating Whitelist Target..."
TARGET_ID=$(curl -s -X POST "$POCKETBASE_URL/api/collections/whitelist_targets/records" \
    -H "Authorization: $SUPERUSER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"PH3 Test Target\", \"pattern\":\"github.com/pocketcoder/*\", \"type\":\"repo\"}" | jq -r '.id')
echo "✅ Target ID: $TARGET_ID"

# 2. Create Action
echo "⚡ Creating Whitelist Action..."
ACTION_ID=$(curl -s -X POST "$POCKETBASE_URL/api/collections/whitelist_actions/records" \
    -H "Authorization: $SUPERUSER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"permission\":\"git\", \"kind\":\"pattern\", \"value\":\"clone *\", \"active\": true}" | jq -r '.id')
echo "✅ Action ID: $ACTION_ID"

# 3. Verify Retrieval
echo "🔍 Verifying Action Data..."
ACTION_DETAIL=$(curl -s "$POCKETBASE_URL/api/collections/whitelist_actions/records/$ACTION_ID" \
    -H "Authorization: $SUPERUSER_TOKEN")

PERMISSION=$(echo $ACTION_DETAIL | jq -r '.permission')
VALUE=$(echo $ACTION_DETAIL | jq -r '.value')

if [[ "$PERMISSION" == "git" ]] && [[ "$VALUE" == "clone *" ]]; then
    echo "✅ Whitelist Persistence Working."
else
    echo "❌ Whitelist Verification Failed."
    echo "Response: $ACTION_DETAIL"
    exit 1
fi

echo "🏁 WHITELIST FEATURE TEST PASSED!"
