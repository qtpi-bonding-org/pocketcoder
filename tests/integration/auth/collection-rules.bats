#!/usr/bin/env bats
# Collection Auth Rules - Verify PocketBase collection security boundaries
#
# These tests validate that collection-level auth rules (ListRule, CreateRule, etc.)
# are correctly enforced. No LLM required.
#
# Users seeded by migrations:
#   - admin user (POCKETBASE_ADMIN_EMAIL, role=admin)
#   - agent user (AGENT_EMAIL, role=agent)

load '../../helpers/auth.sh'
load '../../helpers/cleanup.sh'
load '../../helpers/assertions.sh'
load '../../helpers/tracking.sh'

setup() {
    load_env
    TEST_ID=$(generate_test_id)
    export CURRENT_TEST_ID="$TEST_ID"
}

teardown() {
    cleanup_test_data "$TEST_ID" || true
}

# ---------------------------------------------------------------------------
# 1. Unauthenticated access denied
# ---------------------------------------------------------------------------
@test "Auth Rules: unauthenticated list on chats returns empty results" {
    local response
    response=$(curl -s "$PB_URL/api/collections/chats/records")

    # PocketBase returns 200 with empty items for list rules that require auth
    local total_items
    total_items=$(echo "$response" | jq -r '.totalItems // 0')
    echo "Unauthenticated chats totalItems: $total_items"
    [ "$total_items" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 2. SOPs admin-only write
# ---------------------------------------------------------------------------
@test "Auth Rules: agent cannot create SOP records (no direct creation)" {
    authenticate_agent

    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X POST "$PB_URL/api/collections/sops/records" \
        -H "Authorization: $AGENT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"test-sop-$TEST_ID\", \"description\": \"test\", \"content\": \"test\", \"signature\": \"test\"}")

    local http_code
    http_code=$(echo "$response" | tail -1)

    echo "Agent create SOP HTTP status: $http_code"
    # SOPs have empty CreateRule — no direct creation allowed (403 or 400)
    [ "$http_code" -eq 403 ] || [ "$http_code" -eq 400 ]
}

@test "Auth Rules: superuser can create SOP records (bypasses collection rules)" {
    authenticate_user  # superuser role

    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X POST "$PB_URL/api/collections/sops/records" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"test-sop-$TEST_ID\", \"description\": \"test\", \"content\": \"test\", \"signature\": \"test\"}")

    local http_code
    http_code=$(echo "$response" | tail -1)

    echo "Superuser create SOP HTTP status: $http_code"
    # Superusers bypass collection rules — can create even with empty CreateRule
    [ "$http_code" -eq 200 ]

    # Clean up
    local record_id
    record_id=$(echo "$response" | head -n -1 | jq -r '.id // empty')
    [ -n "$record_id" ] && track_artifact "sops:$record_id"
}

# ---------------------------------------------------------------------------
# 3. Custom endpoints require auth
# ---------------------------------------------------------------------------
@test "Auth Rules: POST /api/pocketcoder/permission without token returns 401" {
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$PB_URL/api/pocketcoder/permission" \
        -H "Content-Type: application/json" \
        -d '{"test": true}')

    echo "Unauthenticated custom endpoint HTTP status: $http_code"
    [ "$http_code" -eq 401 ] || [ "$http_code" -eq 403 ]
}

# ---------------------------------------------------------------------------
# 4. Tool permissions admin-only write
# ---------------------------------------------------------------------------
@test "Auth Rules: agent cannot create tool_permissions (admin-only)" {
    authenticate_agent

    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X POST "$PB_URL/api/collections/tool_permissions/records" \
        -H "Authorization: $AGENT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"agent\": \"$AGENT_ID\", \"tool\": \"test-$TEST_ID\", \"pattern\": \"*\", \"action\": \"deny\", \"active\": true}")

    local http_code
    http_code=$(echo "$response" | tail -1)

    echo "Agent create tool_permissions HTTP status: $http_code"
    # Agent role is not admin — should be denied (403 or 400 if validation runs first)
    [ "$http_code" -eq 403 ] || [ "$http_code" -eq 400 ]
}

@test "Auth Rules: admin can create tool_permissions" {
    authenticate_user  # admin role
    authenticate_agent  # need agent ID for the relation field

    local response
    response=$(curl -s -X POST "$PB_URL/api/collections/tool_permissions/records" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"agent\": \"$AGENT_ID\", \"tool\": \"test-$TEST_ID\", \"pattern\": \"*\", \"action\": \"deny\", \"active\": true}")

    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    echo "Admin create tool_permissions result: id=$record_id"

    [ -n "$record_id" ] && [ "$record_id" != "null" ]
    track_artifact "tool_permissions:$record_id"
}
