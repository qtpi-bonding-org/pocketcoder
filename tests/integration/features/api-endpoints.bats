#!/usr/bin/env bats
# Feature: PocketBase Custom API Endpoints
#
# Lightweight happy-path tests for PocketCoder custom API endpoints.
# No LLM required.
#
# Tests:
# 1. POST /api/pocketcoder/permission — create permission record
# 2. POST /api/pocketcoder/mcp_request — create/deduplicate MCP server requests
# 3. GET /api/pocketcoder/ssh_keys — retrieve SSH public keys
# 4. POST /api/pocketcoder/push — send push notification
# 5. Cron API — schedule, list, cancel scheduled tasks

load '../../helpers/auth.sh'
load '../../helpers/cleanup.sh'
load '../../helpers/assertions.sh'
load '../../helpers/diagnostics.sh'
load '../../helpers/tracking.sh'

setup() {
    load_env
    TEST_ID=$(generate_test_id)
    export CURRENT_TEST_ID="$TEST_ID"
}

teardown() {
    cleanup_test_data "$TEST_ID" || true
    # Clean up any tracked artifacts not handled by cleanup_test_data
    cleanup_tracked_artifacts || true
}

# =============================================================================
# Helpers
# =============================================================================

# Authenticate as agent and set both AGENT_TOKEN and USER_TOKEN (for pb_* helpers)
setup_agent_auth() {
    authenticate_agent
    # pb_request and friends use USER_TOKEN, so alias it
    USER_TOKEN="$AGENT_TOKEN"
    USER_ID="$AGENT_ID"
    export USER_TOKEN USER_ID
}

# Make an authenticated request to a custom endpoint
# Usage: api_request "POST" "/api/pocketcoder/endpoint" '{"key":"value"}'
api_request() {
    local method="$1"
    local path="$2"
    local data="${3:-}"

    local opts=("-s" "-X" "$method")
    if [ -n "$data" ]; then
        opts+=("-H" "Content-Type: application/json" "-d" "$data")
    fi

    curl "${opts[@]}" \
        -H "Authorization: $AGENT_TOKEN" \
        "$PB_URL$path"
}

# Create a test chat linked to the human user, with a fake session ID.
# Requires USER_TOKEN to be a user (not agent) or superuser with write access.
# Args: session_id
# Returns: chat record ID
create_test_chat_with_session() {
    local session_id="$1"

    # We need to create the chat as the human user, so authenticate as user first
    authenticate_user
    local human_token="$USER_TOKEN"
    local human_id="$USER_ID"

    local response
    response=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
        -H "Authorization: $human_token" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"$TEST_ID cron test chat\",
            \"user\": \"$human_id\",
            \"ai_engine_session_id\": \"$session_id\"
        }")

    local chat_id
    chat_id=$(echo "$response" | jq -r '.id // empty')
    if [ -n "$chat_id" ]; then
        track_artifact "chats:$chat_id"
    fi

    # Restore agent auth
    setup_agent_auth

    echo "$chat_id"
}

# =============================================================================
# 1. POST /api/pocketcoder/permission
# =============================================================================

@test "permission: agent can create permission record with draft status" {
    setup_agent_auth

    # Create a test chat to link the permission to
    authenticate_user
    local human_token="$USER_TOKEN"
    local human_id="$USER_ID"
    local chat_response
    chat_response=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
        -H "Authorization: $human_token" \
        -H "Content-Type: application/json" \
        -d "{\"title\": \"$TEST_ID perm chat\", \"user\": \"$human_id\"}")
    local chat_id
    chat_id=$(echo "$chat_response" | jq -r '.id // empty')
    assert_not_empty "$chat_id" "Chat should be created"
    track_artifact "chats:$chat_id"

    # Switch back to agent auth
    setup_agent_auth

    local response
    response=$(api_request "POST" "/api/pocketcoder/permission" "{
        \"permission\": \"file.write\",
        \"patterns\": [\"*.txt\"],
        \"chat_id\": \"$chat_id\",
        \"session_id\": \"$TEST_ID-session\",
        \"opencode_id\": \"$TEST_ID-oc\",
        \"metadata\": {\"test\": true},
        \"message\": \"Test permission request\",
        \"message_id\": \"$TEST_ID-msg\",
        \"call_id\": \"$TEST_ID-call\"
    }")

    # Verify response structure
    local perm_id status permitted
    perm_id=$(echo "$response" | jq -r '.id // empty')
    status=$(echo "$response" | jq -r '.status // empty')
    # Use 'if' to handle boolean false correctly (jq's // treats false as falsy)
    permitted=$(echo "$response" | jq -r 'if .permitted then "true" else "false" end')

    assert_not_empty "$perm_id" "Response should have an id"
    assert_equal "draft" "$status" "Status should be draft"
    assert_equal "false" "$permitted" "Permitted should be false"

    track_artifact "permissions:$perm_id"
}

@test "permission: created record has a challenge UUID" {
    setup_agent_auth

    # Create prerequisite chat
    authenticate_user
    local chat_response
    chat_response=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"title\": \"$TEST_ID challenge chat\", \"user\": \"$USER_ID\"}")
    local chat_id
    chat_id=$(echo "$chat_response" | jq -r '.id // empty')
    track_artifact "chats:$chat_id"

    setup_agent_auth

    local response
    response=$(api_request "POST" "/api/pocketcoder/permission" "{
        \"permission\": \"shell.exec\",
        \"patterns\": [],
        \"chat_id\": \"$chat_id\",
        \"session_id\": \"$TEST_ID-session\",
        \"opencode_id\": \"$TEST_ID-oc2\",
        \"metadata\": {},
        \"message\": \"Test challenge\",
        \"message_id\": \"$TEST_ID-msg2\",
        \"call_id\": \"$TEST_ID-call2\"
    }")

    local perm_id
    perm_id=$(echo "$response" | jq -r '.id // empty')
    assert_not_empty "$perm_id" "Response should have an id"
    track_artifact "permissions:$perm_id"

    # Fetch the record directly to verify the challenge field
    local record
    record=$(pb_get "permissions" "$perm_id")
    local challenge
    challenge=$(echo "$record" | jq -r '.challenge // empty')
    assert_not_empty "$challenge" "Record should have a challenge UUID"
}

# =============================================================================
# 2. POST /api/pocketcoder/mcp_request
# =============================================================================

@test "mcp_request: agent can create MCP server request with pending status" {
    setup_agent_auth

    local server_name="${TEST_ID}-testmcp"
    local response
    response=$(api_request "POST" "/api/pocketcoder/mcp_request" "{
        \"server_name\": \"$server_name\",
        \"reason\": \"Integration test\",
        \"session_id\": \"$TEST_ID-session\",
        \"image\": \"mcp/test:latest\",
        \"config_schema\": {\"key\": \"string\"}
    }")

    local mcp_id status
    mcp_id=$(echo "$response" | jq -r '.id // empty')
    status=$(echo "$response" | jq -r '.status // empty')

    assert_not_empty "$mcp_id" "Response should have an id"
    assert_equal "pending" "$status" "Status should be pending"

    track_artifact "mcp_servers:$mcp_id"
}

@test "mcp_request: duplicate server_name returns existing record with synced flag" {
    setup_agent_auth

    local server_name="${TEST_ID}-dupmcp"

    # First request — creates the record
    local first_response
    first_response=$(api_request "POST" "/api/pocketcoder/mcp_request" "{
        \"server_name\": \"$server_name\",
        \"reason\": \"First request\",
        \"session_id\": \"$TEST_ID-session\",
        \"image\": \"mcp/dup:latest\",
        \"config_schema\": {}
    }")

    local first_id
    first_id=$(echo "$first_response" | jq -r '.id // empty')
    assert_not_empty "$first_id" "First request should return an id"
    track_artifact "mcp_servers:$first_id"

    # Second request — same server_name, should deduplicate
    local second_response
    second_response=$(api_request "POST" "/api/pocketcoder/mcp_request" "{
        \"server_name\": \"$server_name\",
        \"reason\": \"Second request\",
        \"session_id\": \"$TEST_ID-session2\",
        \"image\": \"mcp/dup:v2\",
        \"config_schema\": {}
    }")

    local second_id synced
    second_id=$(echo "$second_response" | jq -r '.id // empty')
    synced=$(echo "$second_response" | jq -r '.synced // empty')

    assert_equal "$first_id" "$second_id" "Should return the same record ID"
    assert_equal "true" "$synced" "Should indicate synced (not a new record)"
}

# =============================================================================
# 3. GET /api/pocketcoder/ssh_keys
# =============================================================================

@test "ssh_keys: agent can retrieve SSH keys as text" {
    setup_agent_auth

    local response
    response=$(api_request "GET" "/api/pocketcoder/ssh_keys")

    # Response should be plain text (not JSON). It may be empty if no keys exist,
    # but it should NOT be a JSON error object.
    local is_json_error
    is_json_error=$(echo "$response" | jq -r '.error // empty' 2>/dev/null || echo "")
    assert_equal "" "$is_json_error" "Response should not be a JSON error"
}

@test "ssh_keys: created SSH key appears in endpoint response" {
    # SSH keys require user = @request.auth.id, so create as admin user
    authenticate_user
    local human_token="$USER_TOKEN"
    local human_id="$USER_ID"

    local test_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey${TEST_ID} test@pocketcoder"

    # Create an SSH key record via the PB API (must include user and fingerprint fields)
    local fingerprint="SHA256:$(echo -n "$test_key" | sha256sum | awk '{print $1}' | head -c 43)"
    local create_response
    create_response=$(curl -s -X POST "$PB_URL/api/collections/ssh_keys/records" \
        -H "Authorization: $human_token" \
        -H "Content-Type: application/json" \
        -d "{
            \"user\": \"$human_id\",
            \"device_name\": \"$TEST_ID test key\",
            \"public_key\": \"$test_key\",
            \"fingerprint\": \"$fingerprint\",
            \"is_active\": true
        }")

    local key_id
    key_id=$(echo "$create_response" | jq -r '.id // empty')
    assert_not_empty "$key_id" "SSH key record should be created"
    track_artifact "ssh_keys:$key_id"

    # Switch to agent auth for the custom endpoint
    setup_agent_auth

    # Now fetch via the custom endpoint
    local response
    response=$(api_request "GET" "/api/pocketcoder/ssh_keys")

    assert_contains "$response" "$test_key" "SSH key should appear in endpoint response"
}

# =============================================================================
# 4. POST /api/pocketcoder/push
# =============================================================================

@test "push: agent can send push notification and gets ok response" {
    setup_agent_auth

    # Get the human user ID for the push target
    authenticate_user
    local human_id="$USER_ID"
    setup_agent_auth

    local response
    response=$(api_request "POST" "/api/pocketcoder/push" "{
        \"user_id\": \"$human_id\",
        \"title\": \"Test Notification $TEST_ID\",
        \"message\": \"This is a test push\",
        \"type\": \"task_complete\",
        \"chat\": \"\"
    }")

    local ok
    ok=$(echo "$response" | jq -r '.ok // empty')
    assert_equal "true" "$ok" "Response should have ok=true"
}

@test "push: missing required fields returns 400" {
    setup_agent_auth

    # Missing user_id and type
    local response
    response=$(api_request "POST" "/api/pocketcoder/push" "{
        \"title\": \"Bad Request\",
        \"message\": \"No user_id or type\"
    }")

    local error
    error=$(echo "$response" | jq -r '.error // empty')
    assert_not_empty "$error" "Should return an error message"
    assert_contains "$error" "required" "Error should mention required fields"
}

# =============================================================================
# 5. Cron API
# =============================================================================

@test "cron: agent can schedule, list, and cancel a task" {
    setup_agent_auth

    # The cron API requires a chat with ai_engine_session_id to resolve the human user.
    local session_id="${TEST_ID}-cron-session"
    local chat_id
    chat_id=$(create_test_chat_with_session "$session_id")
    assert_not_empty "$chat_id" "Test chat should be created for cron tests"

    # --- Schedule a task ---
    local schedule_response
    schedule_response=$(api_request "POST" "/api/pocketcoder/schedule_task" "{
        \"name\": \"$TEST_ID cron job\",
        \"cron_expression\": \"0 9 * * *\",
        \"prompt\": \"Run daily health check\",
        \"session_mode\": \"new\",
        \"description\": \"Test cron job\",
        \"session_id\": \"$session_id\"
    }")

    local task_id task_status task_name
    task_id=$(echo "$schedule_response" | jq -r '.id // empty')
    task_status=$(echo "$schedule_response" | jq -r '.status // empty')
    task_name=$(echo "$schedule_response" | jq -r '.name // empty')

    assert_not_empty "$task_id" "Schedule response should have an id"
    assert_equal "scheduled" "$task_status" "Status should be scheduled"
    assert_contains "$task_name" "$TEST_ID" "Name should contain test ID"

    track_artifact "cron_jobs:$task_id"

    # --- List tasks ---
    local list_response
    list_response=$(api_request "GET" "/api/pocketcoder/scheduled_tasks?session_id=$session_id")

    # Response is a JSON array
    local list_count
    list_count=$(echo "$list_response" | jq 'length')
    assert_not_empty "$list_count" "List should return an array"

    # Find our task in the list
    local found_id
    found_id=$(echo "$list_response" | jq -r ".[] | select(.id == \"$task_id\") | .id")
    assert_equal "$task_id" "$found_id" "Created task should appear in the list"

    # --- Cancel the task ---
    local cancel_response
    cancel_response=$(api_request "POST" "/api/pocketcoder/cancel_scheduled_task" "{
        \"task_id\": \"$task_id\"
    }")

    local cancel_status cancel_id
    cancel_status=$(echo "$cancel_response" | jq -r '.status // empty')
    cancel_id=$(echo "$cancel_response" | jq -r '.id // empty')

    assert_equal "cancelled" "$cancel_status" "Cancel status should be cancelled"
    assert_equal "$task_id" "$cancel_id" "Cancel should return the same task ID"
}

@test "cron: schedule_task validates required fields" {
    setup_agent_auth

    # Missing name, cron_expression, prompt
    local response
    response=$(api_request "POST" "/api/pocketcoder/schedule_task" "{
        \"description\": \"Missing required fields\"
    }")

    local error
    error=$(echo "$response" | jq -r '.error // empty')
    assert_not_empty "$error" "Should return an error for missing required fields"
}
