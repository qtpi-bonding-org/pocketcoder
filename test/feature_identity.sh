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


# @pocketcoder-core: Identity Test. Verifies correct token handling and permission gating for AI sessions.
#!/bin/bash
# test/feature_identity.sh
# Tests Phase 4: Agent Identity Persistence (Update Loop)

POCKETBASE_URL="http://127.0.0.1:8090"

# Load from .env
if [ -f .env ]; then
    ADMIN_EMAIL=$(grep "^POCKETBASE_SUPERUSER_EMAIL=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
    ADMIN_PASS=$(grep "^POCKETBASE_SUPERUSER_PASSWORD=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
else
    echo "❌ .env file not found."
    exit 1
fi

echo "🔐 [Identity] Authenticating..."
AUTH_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$ADMIN_EMAIL\", \"password\":\"$ADMIN_PASS\"}")
ADMIN_TOKEN=$(echo $AUTH_RES | jq -r '.token')

# 1. Reuse or Create an Agent
# We'll create a fresh one for the test
PROMPT_ID=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ai_prompts/records" \
    -H "Authorization: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"ID Test Prompt\", \"body\":\"Initial Prompt\"}" | jq -r '.id')

MODEL_ID=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ai_models/records" \
    -H "Authorization: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"ID Test Model\", \"identifier\":\"gpt-3.5\"}" | jq -r '.id')

AGENT_ID=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ai_agents/records" \
    -H "Authorization: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\":\"identity_update_agent\",
        \"is_init\": true,
        \"mode\": \"primary\",
        \"prompt\": \"$PROMPT_ID\",
        \"model\": \"$MODEL_ID\"
    }" | jq -r '.id')
echo "✅ Created Agent: $AGENT_ID"

# 2. Update Identity (The "Persistence" Test)
echo "🔄 Updating Identity (New Prompt Body)..."
NEW_BODY="Updated Prompt Body - $(date)"
curl -s -X PATCH "$POCKETBASE_URL/api/collections/ai_prompts/records/$PROMPT_ID" \
    -H "Authorization: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"body\":\"$NEW_BODY\"}" > /dev/null

# Now touch the agent to trigger the re-assembly hook (since we only hook on agent save)
# In a real system, we might have a cascade. For now, updating agent metadata triggers it.
echo "⚡ Triggering Agent Re-assembly..."
curl -s -X PATCH "$POCKETBASE_URL/api/collections/ai_agents/records/$AGENT_ID" \
    -H "Authorization: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"description\":\"Updated at $(date)\"}" > /dev/null

# 3. Verify File Change
echo "🔍 Verifying persistent file update (waiting 3s)..."
sleep 3
FILE_CONTENT=$(docker exec pocketcoder-opencode cat /workspace/.opencode/agents/identity_update_agent.md)

if [[ "$FILE_CONTENT" == *"$NEW_BODY"* ]]; then
    echo "✅ Identity Persistence Working: File content updated."
else
    echo "❌ Identity Persistence Failed."
    echo "   Expected containing: $NEW_BODY"
    echo "   File Content: $FILE_CONTENT"
    exit 1
fi

echo "🏁 IDENTITY FEATURE TEST PASSED!"
