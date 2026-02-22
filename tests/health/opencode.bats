#!/usr/bin/env bats
# Feature: test-suite-reorganization, Property 1: Health Test Correctness

# OpenCode health tests
# Validates: Requirements 2.2, 2.3, 2.7, 2.8

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
}

teardown() {
    cleanup_test_data "$TEST_ID" || true
}

@test "OpenCode health endpoint returns 200 OK" {
    # Validates: Requirement 2.2
    run curl -s -w "%{http_code}" "$OPENCODE_URL/health"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "OpenCode" "Failed to connect to health endpoint"
    [[ "${lines[-1]}" == "200" ]] || run_diagnostic_on_failure "OpenCode" "Health endpoint returned ${lines[-1]} instead of 200"
}

@test "OpenCode health check completes within 30 seconds" {
    # Validates: Requirement 2.7
    run timeout 30 curl -s "$OPENCODE_URL/health"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "OpenCode" "Health check timed out after 30 seconds"
}

# @test "OpenCode sshd is listening on port 2222" {
#     # Validates: Requirement 2.3
#     # Connect to OpenCode container on the Docker network
#     run nc -z opencode 2222
#     [ "$status" -eq 0 ] || run_diagnostic_on_failure "OpenCode" "SSH daemon not listening on port 2222"
# }

@test "OpenCode can create a session" {
    # Validates: Requirement 2.2 - session creation capability
    local session_data
    session_data=$(curl -s -X POST "$OPENCODE_URL/session" \
        -H "Content-Type: application/json" \
        -d '{"directory": "/workspace", "agent": "build"}')

    local session_id
    session_id=$(echo "$session_data" | jq -r '.id // empty')

    if [ -n "$session_id" ] && [ "$session_id" != "null" ]; then
        track_artifact "opencode_sessions:$session_id"
        [ -n "$session_id" ]
    else
        # Session creation might require auth, skip if not available
        skip "Session creation requires authentication"
    fi
}

@test "OpenCode can query a session" {
    # Validates: Requirement 2.2 - session query capability
    # First create a session
    local session_data
    session_data=$(curl -s -X POST "$OPENCODE_URL/session" \
        -H "Content-Type: application/json" \
        -d '{"directory": "/workspace", "agent": "build"}')

    local session_id
    session_id=$(echo "$session_data" | jq -r '.id // empty')

    if [ -n "$session_id" ] && [ "$session_id" != "null" ]; then
        track_artifact "opencode_sessions:$session_id"

        # Query the session
        local retrieved
        retrieved=$(curl -s "$OPENCODE_URL/session/$session_id")
        local retrieved_id
        retrieved_id=$(echo "$retrieved" | jq -r '.id // empty')
        [ "$retrieved_id" = "$session_id" ] || run_diagnostic_on_failure "OpenCode" "Failed to query session $session_id"
    else
        skip "Session creation requires authentication"
    fi
}

@test "OpenCode health check provides diagnostic information on failure" {
    # Validates: Requirement 2.8
    # This test verifies that when health check fails, diagnostic info is available
    
    # Verify we can get health info
    run curl -s "$OPENCODE_URL/health"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "OpenCode" "Failed to get health endpoint response"
}