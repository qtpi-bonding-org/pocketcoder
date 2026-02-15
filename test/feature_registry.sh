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

# @pocketcoder-core: Registry Test. Confirms AI prompts and sessions are correctly persisted.
#!/bin/bash
# test/feature_registry.sh
# Tests Phase 1: AI Registry, Go Hooks, and Relay Sync

POCKETBASE_URL="http://127.0.0.1:8090"

# Load from .env
if [ -f .env ]; then
    ADMIN_EMAIL=$(grep "^POCKETBASE_SUPERUSER_EMAIL=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
    ADMIN_PASS=$(grep "^POCKETBASE_SUPERUSER_PASSWORD=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
else
    echo "❌ .env file not found."
    exit 1
fi

echo "🔐 [Registry] Authenticating..."
AUTH_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$ADMIN_EMAIL\", \"password\":\"$ADMIN_PASS\"}")
ADMIN_TOKEN=$(echo $AUTH_RES | jq -r '.token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" == "null" ]; then
    echo "❌ Auth Failed"
    exit 1
fi

# 1. Create Prompt
echo "📝 Creating Prompt..."
PROMPT_ID=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ai_prompts/records" \
    -H "Authorization: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Registry Test Prompt\", \"body\":\"You are a test orchestrator.\"}" | jq -r '.id')

# 2. Create Model
echo "🤖 Creating Model..."
MODEL_ID=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ai_models/records" \
    -H "Authorization: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Registry Test Model\", \"identifier\":\"gpt-4\"}" | jq -r '.id')

# 3. Create Agent
echo "💂 Creating Agent (Poco)..."
AGENT_ID=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ai_agents/records" \
    -H "Authorization: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\":\"reg_test_agent\",
        \"is_init\": true,
        \"mode\": \"primary\",
        \"prompt\": \"$PROMPT_ID\",
        \"model\": \"$MODEL_ID\"
    }" | jq -r '.id')

echo "✅ Created Agent: $AGENT_ID"

# 4. Verify Assembly Hook
echo "🔍 Verifying Assembly (waiting 2s)..."
sleep 2
AGENT_DETAIL=$(curl -s "$POCKETBASE_URL/api/collections/ai_agents/records/$AGENT_ID" \
    -H "Authorization: $ADMIN_TOKEN")
CONFIG=$(echo $AGENT_DETAIL | jq -r '.config')

if [[ "$CONFIG" == *"You are a test orchestrator"* ]] && [[ "$CONFIG" == *"model: gpt-4"* ]]; then
    echo "✅ Assembly Hook Working: Config contains prompt and model metadata."
else
    echo "❌ Assembly Hook Failed."
    echo "Config: $CONFIG"
    exit 1
fi

# 5. Verify Relay Sync
echo "🚀 Verifying Relay Sync..."
sleep 2
docker exec pocketcoder-opencode ls /workspace/.opencode/agents/reg_test_agent.md > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Relay Sync Working: File deployed to opencode vessel."
else
    echo "❌ Relay Sync Failed: File not found in opencode."
    exit 1
fi

echo "🏁 REGISTRY FEATURE TEST PASSED!"
