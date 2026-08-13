#!/usr/bin/env bats
# Feature: PocketCoder imperative API operations that are not collection CRUD.

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
    cleanup_tracked_artifacts || true
}

api_request() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local token="${USER_TOKEN:-}"
    local args=(-s -X "$method" "$PB_URL$endpoint" -H "Authorization: $token")
    if [ -n "$data" ]; then
        args+=(-H "Content-Type: application/json" -d "$data")
    fi
    curl "${args[@]}"
}

@test "mcp_request creates a pending request" {
    setup_agent_auth
    local name="${TEST_ID}-mcp"
    local response
    response=$(api_request "POST" "/api/pocketcoder/mcp_request" "{
        \"server_name\": \"$name\",
        \"reason\": \"Integration test\",
        \"session_id\": \"$TEST_ID\",
        \"image\": \"mcp/test:latest\",
        \"config_schema\": {}
    }")

    local id status
    id=$(echo "$response" | jq -r '.id // empty')
    status=$(echo "$response" | jq -r '.status // empty')
    assert_not_empty "$id" "MCP request ID should not be empty"
    assert_equal "pending" "$status" "MCP request should be pending"
    track_artifact "mcp_servers:$id"
}

@test "mcp_request deduplicates the same server name" {
    setup_agent_auth
    local name="${TEST_ID}-duplicate"
    local first second
    first=$(api_request "POST" "/api/pocketcoder/mcp_request" "{
        \"server_name\": \"$name\",
        \"reason\": \"First\",
        \"session_id\": \"$TEST_ID-first\",
        \"image\": \"mcp/test:v1\",
        \"config_schema\": {}
    }")
    second=$(api_request "POST" "/api/pocketcoder/mcp_request" "{
        \"server_name\": \"$name\",
        \"reason\": \"Second\",
        \"session_id\": \"$TEST_ID-second\",
        \"image\": \"mcp/test:v2\",
        \"config_schema\": {}
    }")

    assert_equal "$(echo "$first" | jq -r '.id')" "$(echo "$second" | jq -r '.id')" "MCP request should reuse the existing record"
    assert_equal "true" "$(echo "$second" | jq -r '.synced')" "Second request should report synchronization"
}

@test "push validates required fields" {
    setup_agent_auth
    local response
    response=$(api_request "POST" "/api/pocketcoder/push" '{"title":"Bad Request","message":"Missing target"}')
    assert_not_empty "$(echo "$response" | jq -r '.error // empty')" "Push should reject missing fields"
}
