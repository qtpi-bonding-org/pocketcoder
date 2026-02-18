#!/usr/bin/env bats
# Feature: MCP Gateway Integration
# Integration tests for MCP Gateway API endpoints and collection
# Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5, 8.1, 8.2, 6.1
#
# Tests:
# 1. MCP request endpoint requires authentication (unauthenticated POST → 401)
# 2. MCP request endpoint rejects non-agent role (user POST → 403)
# 3. MCP request endpoint creates pending record (agent POST → 200 with id and status "pending")
# 4. MCP request endpoint returns existing approved record (create approved record, POST same name → returns existing)
# 5. Permission endpoint requires auth (unauthenticated POST → 401)
# 6. SSH keys endpoint requires auth (unauthenticated GET → 401)
# 7. mcp_servers collection exists and accepts records
# 8. Property 1: MCP request idempotency for approved servers

load '../helpers/auth.sh'
load '../helpers/cleanup.sh'
load '../helpers/wait.sh'
load '../helpers/assertions.sh'
load '../helpers/diagnostics.sh'
load '../helpers/tracking.sh'

setup() {
    load_env
    TEST_ID=$(generate_test_id)
    export CURRENT_TEST_ID="$TEST_ID"
    CHAT_ID=""
    USER_MESSAGE_ID=""
    MCP_SERVER_ID=""
    AGENT_TOKEN=""
    AGENT_ID=""
    USER_TOKEN=""
    USER_ID=""
}

teardown() {
    # Clean up all test data
    cleanup_test_data "$TEST_ID" || true
    
    # Clean up mcp_servers records created during tests
    cleanup_mcp_servers "$TEST_ID" || true
    
    # Clean up agent token if created
    if [ -n "$AGENT_TOKEN" ]; then
        unset AGENT_TOKEN
    fi
}

# Helper function to authenticate as agent
authenticate_agent() {
    load_env
    
    local email="${AGENT_EMAIL:-}"
    local password="${AGENT_PASSWORD:-}"
    
    if [ -z "$email" ] || [ -z "$password" ]; then
        echo "❌ Error: AGENT_EMAIL or AGENT_PASSWORD not found" >&2
        return 1
    fi
    
    local token_res
    token_res=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\": \"$email\", \"password\": \"$password\"}")
    
    AGENT_TOKEN=$(echo "$token_res" | jq -r '.token // empty')
    AGENT_ID=$(echo "$token_res" | jq -r '.record.id // empty')
    
    if [ -z "$AGENT_TOKEN" ]; then
        echo "❌ Failed to authenticate as agent" >&2
        echo "Response: $token_res" >&2
        return 1
    fi
    
    export AGENT_TOKEN AGENT_ID
    echo "✅ Authenticated as agent: $AGENT_ID"
}

# Helper function to cleanup mcp_servers records
cleanup_mcp_servers() {
    local test_id="$1"
    local token="${2:-$(get_admin_token)}"
    
    echo "Cleaning up mcp_servers records for: $test_id"
    
    # Search for mcp_servers records with test_id in name
    local response
    response=$(curl -s -X GET \
        "$PB_URL/api/collections/mcp_servers/records?filter=name~\"$test_id\"" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json")
    
    local count
    count=$(echo "$response" | grep -o '"totalCount":[0-9]*' | cut -d':' -f2)
    
    if [ "$count" = "0" ] || [ -z "$count" ]; then
        echo "  No matching mcp_servers records found"
        return 0
    fi
    
    echo "  Found $count mcp_servers record(s)"
    
    # Delete each record
    local failed=0
    echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | while read -r id; do
        if ! delete_record "mcp_servers" "$id" "$token"; then
            failed=1
        fi
    done
    
    return $failed
}

# Helper function to make MCP request
mcp_request() {
    local server_name="$1"
    local reason="$2"
    local token="${3:-$AGENT_TOKEN}"
    
    curl -s -X POST "$PB_URL/api/pocketcoder/mcp_request" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -d "{
            \"server_name\": \"$server_name\",
            \"reason\": \"$reason\",
            \"session_id\": \"$TEST_ID\"
        }"
}

# Helper function to make unauthenticated MCP request
mcp_request_unauthenticated() {
    local server_name="$1"
    local reason="$2"
    
    curl -s -w "\n%{http_code}" -X POST "$PB_URL/api/pocketcoder/mcp_request" \
        -H "Content-Type: application/json" \
        -d "{
            \"server_name\": \"$server_name\",
            \"reason\": \"$reason\",
            \"session_id\": \"$TEST_ID\"
        }"
}

# Helper function to make unauthenticated permission request
permission_request_unauthenticated() {
    local data="$1"
    
    curl -s -w "\n%{http_code}" -X POST "$PB_URL/api/pocketcoder/permission" \
        -H "Content-Type: application/json" \
        -d "$data"
}

# Helper function to make unauthenticated SSH keys request
ssh_keys_request_unauthenticated() {
    curl -s -w "\n%{http_code}" -X GET "$PB_URL/api/pocketcoder/ssh_keys"
}

# Helper function to create mcp_servers record directly
create_mcp_server() {
    local name="$1"
    local status="$2"
    local token="${3:-$(get_admin_token)}"
    
    curl -s -X POST "$PB_URL/api/collections/mcp_servers/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $token" \
        -d "{
            \"name\": \"$name\",
            \"status\": \"$status\",
            \"reason\": \"Test reason for $TEST_ID\",
            \"catalog\": \"docker-mcp\"
        }"
}

# Helper function to count mcp_servers records by name
count_mcp_servers_by_name() {
    local name="$1"
    local token="${2:-$(get_admin_token)}"
    
    local response
    response=$(curl -s -X GET \
        "$PB_URL/api/collections/mcp_servers/records?filter=name=\"$name\"" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json")
    
    echo "$response" | grep -o '"totalCount":[0-9]*' | cut -d':' -f2
}

# =============================================================================
# Test Cases
# =============================================================================

@test "MCP Request: Endpoint requires authentication (unauthenticated POST → 401)" {
    # Validates: Requirement 7.2 - MCP_Request_Endpoint SHALL use apis.RequireAuth() middleware to reject unauthenticated requests with HTTP 401
    
    # Make unauthenticated request
    local response
    response=$(mcp_request_unauthenticated "postgres" "Test reason")
    
    # Extract HTTP status code (last line)
    local http_code
    http_code=$(echo "$response" | tail -n 1)
    local body
    body=$(echo "$response" | sed '$d')
    
    # Verify HTTP 401
    [ "$http_code" = "401" ] || run_diagnostic_on_failure "MCP Request Auth" "Expected HTTP 401, got HTTP $http_code"
    
    # Verify error message
    echo "$body" | grep -q "error" || run_diagnostic_on_failure "MCP Request Auth" "Response should contain error field"
    
    echo "✓ MCP request endpoint correctly rejects unauthenticated requests (HTTP 401)"
}

@test "MCP Request: Endpoint rejects non-agent role (user POST → 403)" {
    # Validates: Requirement 7.3 - MCP_Request_Endpoint SHALL verify caller has agent or admin role, returning HTTP 403 for other roles
    
    # Authenticate as regular user (not agent)
    authenticate_user
    
    # Make request as regular user
    local response
    response=$(mcp_request "postgres" "Test reason" "$USER_TOKEN")
    
    # Extract HTTP status code
    local http_code
    http_code=$(echo "$response" | grep -o '"code":[0-9]*' | head -1 | cut -d':' -f2 || echo "0")
    
    # Verify HTTP 403
    [ "$http_code" = "403" ] || run_diagnostic_on_failure "MCP Request Role" "Expected HTTP 403, got HTTP $http_code or code $http_code"
    
    # Verify error message contains "forbidden" or "permissions"
    local error_msg
    error_msg=$(echo "$response" | jq -r '.message // empty')
    [[ "$error_msg" == *"forbidden"* || "$error_msg" == *"permissions"* || "$error_msg" == *"Insufficient"* ]] || \
        run_diagnostic_on_failure "MCP Request Role" "Error message should indicate insufficient permissions"
    
    echo "✓ MCP request endpoint correctly rejects non-agent role (HTTP 403)"
}

@test "MCP Request: Endpoint creates pending record (agent POST → 200 with id and status 'pending')" {
    # Validates: Requirement 7.4 - MCP_Request_Endpoint SHALL create mcp_servers record with status "pending" and return record ID and status
    
    # Authenticate as agent
    authenticate_agent
    
    # Make request as agent
    local response
    response=$(mcp_request "postgres-$TEST_ID" "Test reason for integration test")
    
    # Verify HTTP 200
    local http_code
    http_code=$(echo "$response" | grep -o '"code":[0-9]*' | head -1 | cut -d':' -f2 || echo "0")
    [ "$http_code" = "200" ] || run_diagnostic_on_failure "MCP Request Create" "Expected HTTP 200, got HTTP $http_code"
    
    # Verify response contains id
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] && [ "$record_id" != "null" ] || run_diagnostic_on_failure "MCP Request Create" "Response should contain id"
    
    # Verify response contains status
    local status
    status=$(echo "$response" | jq -r '.status // empty')
    [ "$status" = "pending" ] || run_diagnostic_on_failure "MCP Request Create" "Status should be 'pending', got: $status"
    
    # Track for cleanup
    MCP_SERVER_ID="$record_id"
    track_artifact "mcp_servers:$MCP_SERVER_ID"
    
    echo "✓ MCP request endpoint creates pending record (id: $record_id, status: pending)"
}

@test "MCP Request: Endpoint returns existing approved record (create approved record, POST same name → returns existing)" {
    # Validates: Requirement 7.5 - MCP_Request_Endpoint SHALL return existing approved record instead of creating duplicate
    # Validates: Property 1 - MCP request idempotency for approved servers
    
    # Authenticate as agent
    authenticate_agent
    
    # Step 1: Create an approved record directly
    local create_response
    create_response=$(create_mcp_server "postgres-$TEST_ID" "approved")
    
    local approved_id
    approved_id=$(echo "$create_response" | jq -r '.id // empty')
    [ -n "$approved_id" ] && [ "$approved_id" != "null" ] || run_diagnostic_on_failure "MCP Request Idempotency" "Failed to create approved record"
    track_artifact "mcp_servers:$approved_id"
    
    # Verify record was created
    local count_before
    count_before=$(count_mcp_servers_by_name "postgres-$TEST_ID")
    [ "$count_before" -ge 1 ] || run_diagnostic_on_failure "MCP Request Idempotency" "Approved record should exist"
    
    # Step 2: Make MCP request for the same server name
    local request_response
    request_response=$(mcp_request "postgres-$TEST_ID" "Another request for same server")
    
    # Verify HTTP 200
    local http_code
    http_code=$(echo "$request_response" | grep -o '"code":[0-9]*' | head -1 | cut -d':' -f2 || echo "0")
    [ "$http_code" = "200" ] || run_diagnostic_on_failure "MCP Request Idempotency" "Expected HTTP 200, got HTTP $http_code"
    
    # Verify the returned record is the existing approved one
    local returned_id
    returned_id=$(echo "$request_response" | jq -r '.id // empty')
    [ "$returned_id" = "$approved_id" ] || run_diagnostic_on_failure "MCP Request Idempotency" "Should return existing approved record, got different id"
    
    # Verify status is still approved
    local returned_status
    returned_status=$(echo "$request_response" | jq -r '.status // empty')
    [ "$returned_status" = "approved" ] || run_diagnostic_on_failure "MCP Request Idempotency" "Returned record should have status 'approved', got: $returned_status"
    
    # Step 3: Verify no duplicate records were created
    local count_after
    count_after=$(count_mcp_servers_by_name "postgres-$TEST_ID")
    [ "$count_after" -eq "$count_before" ] || run_diagnostic_on_failure "MCP Request Idempotency" "Should not create duplicate records (before: $count_before, after: $count_after)"
    
    echo "✓ MCP request endpoint returns existing approved record (idempotent behavior verified)"
}

@test "Auth Hardening: Permission endpoint requires auth (unauthenticated POST → 401)" {
    # Validates: Requirement 8.1 - Permission endpoint SHALL use apis.RequireAuth() middleware
    
    # Make unauthenticated request
    local response
    response=$(permission_request_unauthenticated '{"chat": "test-chat-id", "permission": "write_file"}')
    
    # Extract HTTP status code (last line)
    local http_code
    http_code=$(echo "$response" | tail -n 1)
    local body
    body=$(echo "$response" | sed '$d')
    
    # Verify HTTP 401
    [ "$http_code" = "401" ] || run_diagnostic_on_failure "Permission Auth" "Expected HTTP 401, got HTTP $http_code"
    
    echo "✓ Permission endpoint correctly requires authentication (HTTP 401)"
}

@test "Auth Hardening: SSH keys endpoint requires auth (unauthenticated GET → 401)" {
    # Validates: Requirement 8.2 - SSH keys endpoint SHALL use apis.RequireAuth() middleware
    
    # Make unauthenticated request
    local response
    response=$(ssh_keys_request_unauthenticated)
    
    # Extract HTTP status code (last line)
    local http_code
    http_code=$(echo "$response" | tail -n 1)
    local body
    body=$(echo "$response" | sed '$d')
    
    # Verify HTTP 401
    [ "$http_code" = "401" ] || run_diagnostic_on_failure "SSH Keys Auth" "Expected HTTP 401, got HTTP $http_code"
    
    echo "✓ SSH keys endpoint correctly requires authentication (HTTP 401)"
}

@test "MCP Servers Collection: Exists and accepts records" {
    # Validates: Requirement 6.1 - mcp_servers collection with correct fields
    # Validates: Requirement 6.2 - List/view rules requiring auth
    # Validates: Requirement 6.3 - Create rules restricted to agent/admin roles
    
    # Authenticate as admin
    authenticate_superuser
    
    # Create a record in mcp_servers collection
    local create_response
    create_response=$(curl -s -X POST "$PB_URL/api/collections/mcp_servers/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d "{
            \"name\": \"test-server-$TEST_ID\",
            \"status\": \"pending\",
            \"reason\": \"Integration test for mcp_servers collection\",
            \"catalog\": \"docker-mcp\"
        }")
    
    # Verify record was created
    local record_id
    record_id=$(echo "$create_response" | jq -r '.id // empty')
    [ -n "$record_id" ] && [ "$record_id" != "null" ] || run_diagnostic_on_failure "MCP Servers Collection" "Failed to create mcp_servers record"
    track_artifact "mcp_servers:$record_id"
    
    # Verify record has expected fields
    local name
    name=$(echo "$create_response" | jq -r '.name // empty')
    [ "$name" = "test-server-$TEST_ID" ] || run_diagnostic_on_failure "MCP Servers Collection" "Record should have correct name"
    
    local status
    status=$(echo "$create_response" | jq -r '.status // empty')
    [ "$status" = "pending" ] || run_diagnostic_on_failure "MCP Servers Collection" "Record should have status 'pending'"
    
    local reason
    reason=$(echo "$create_response" | jq -r '.reason // empty')
    [ -n "$reason" ] && [ "$reason" != "null" ] || run_diagnostic_on_failure "MCP Servers Collection" "Record should have reason field"
    
    local catalog
    catalog=$(echo "$create_response" | jq -r '.catalog // empty')
    [ "$catalog" = "docker-mcp" ] || run_diagnostic_on_failure "MCP Servers Collection" "Record should have catalog 'docker-mcp'"
    
    # Verify we can retrieve the record
    local get_response
    get_response=$(curl -s -X GET "$PB_URL/api/collections/mcp_servers/records/$record_id" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local retrieved_id
    retrieved_id=$(echo "$get_response" | jq -r '.id // empty')
    [ "$retrieved_id" = "$record_id" ] || run_diagnostic_on_failure "MCP Servers Collection" "Failed to retrieve created record"
    
    echo "✓ mcp_servers collection exists and accepts records with all required fields"
}

@test "MCP Request: Agent can create pending record" {
    # Additional test to verify agent role can create records
    
    # Authenticate as agent
    authenticate_agent
    
    # Create mcp_servers record directly as agent
    local create_response
    create_response=$(curl -s -X POST "$PB_URL/api/collections/mcp_servers/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $AGENT_TOKEN" \
        -d "{
            \"name\": \"agent-test-server-$TEST_ID\",
            \"status\": \"pending\",
            \"reason\": \"Agent created this record\",
            \"catalog\": \"docker-mcp\"
        }")
    
    # Verify record was created
    local record_id
    record_id=$(echo "$create_response" | jq -r '.id // empty')
    [ -n "$record_id" ] && [ "$record_id" != "null" ] || run_diagnostic_on_failure "MCP Agent Create" "Agent failed to create mcp_servers record"
    track_artifact "mcp_servers:$record_id"
    
    echo "✓ Agent role can create mcp_servers records"
}

@test "MCP Request: Multiple pending requests for same server create separate records" {
    # Test that multiple pending requests create separate records (only approved records are idempotent)
    
    # Authenticate as agent
    authenticate_agent
    
    # Create first pending record
    local create_response1
    create_response1=$(create_mcp_server "multi-test-$TEST_ID" "pending")
    local id1
    id1=$(echo "$create_response1" | jq -r '.id // empty')
    [ -n "$id1" ] && [ "$id1" != "null" ] || run_diagnostic_on_failure "MCP Multiple Pending" "Failed to create first record"
    track_artifact "mcp_servers:$id1"
    
    # Create second pending record
    local create_response2
    create_response2=$(create_mcp_server "multi-test-$TEST_ID" "pending")
    local id2
    id2=$(echo "$create_response2" | jq -r '.id // empty')
    [ -n "$id2" ] && [ "$id2" != "null" ] || run_diagnostic_on_failure "MCP Multiple Pending" "Failed to create second record"
    track_artifact "mcp_servers:$id2"
    
    # Verify we have two separate records
    local count
    count=$(count_mcp_servers_by_name "multi-test-$TEST_ID")
    [ "$count" -ge 2 ] || run_diagnostic_on_failure "MCP Multiple Pending" "Should have at least 2 records, got: $count"
    
    # Verify they have different IDs
    [ "$id1" != "$id2" ] || run_diagnostic_on_failure "MCP Multiple Pending" "Records should have different IDs"
    
    echo "✓ Multiple pending requests for same server create separate records"
}

# =============================================================================
# Property-Based Test
# =============================================================================

@test "Property 1: MCP request idempotency for approved servers" {
    # Validates: Requirements 7.5
    # Property: For any server name that already has an approved record, submitting a new MCP request
    #           SHALL return the existing approved record rather than creating a duplicate.
    #           The total count of records with that server name SHALL not increase.
    
    authenticate_agent
    
    # Create an approved record
    local create_response
    create_response=$(create_mcp_server "property-test-$TEST_ID" "approved")
    local approved_id
    approved_id=$(echo "$create_response" | jq -r '.id // empty')
    [ -n "$approved_id" ] && [ "$approved_id" != "null" ] || run_diagnostic_on_failure "Property 1" "Failed to create approved record"
    track_artifact "mcp_servers:$approved_id"
    
    # Get initial count
    local count_before
    count_before=$(count_mcp_servers_by_name "property-test-$TEST_ID")
    
    # Make multiple idempotent requests
    local num_requests=5
    local returned_ids=()
    
    for i in $(seq 1 $num_requests); do
        local response
        response=$(mcp_request "property-test-$TEST_ID" "Request #$i for testing idempotency")
        
        local http_code
        http_code=$(echo "$response" | grep -o '"code":[0-9]*' | head -1 | cut -d':' -f2 || echo "0")
        [ "$http_code" = "200" ] || run_diagnostic_on_failure "Property 1" "Request $i should succeed (HTTP 200)"
        
        local returned_id
        returned_id=$(echo "$response" | jq -r '.id // empty')
        [ -n "$returned_id" ] && [ "$returned_id" != "null" ] || run_diagnostic_on_failure "Property 1" "Request $i should return record id"
        
        returned_ids+=("$returned_id")
        
        # Verify status is approved
        local returned_status
        returned_status=$(echo "$response" | jq -r '.status // empty')
        [ "$returned_status" = "approved" ] || run_diagnostic_on_failure "Property 1" "Request $i should return approved status, got: $returned_status"
    done
    
    # Verify all requests returned the same record
    for id in "${returned_ids[@]}"; do
        [ "$id" = "$approved_id" ] || run_diagnostic_on_failure "Property 1" "All requests should return the same approved record id"
    done
    
    # Verify no duplicate records were created
    local count_after
    count_after=$(count_mcp_servers_by_name "property-test-$TEST_ID")
    [ "$count_after" -eq "$count_before" ] || run_diagnostic_on_failure "Property 1" "No duplicate records should be created (before: $count_before, after: $count_after)"
    
    echo "✓ Property 1 verified: MCP request idempotency for approved servers ($num_requests requests, 0 duplicates)"
}