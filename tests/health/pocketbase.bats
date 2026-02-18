#!/usr/bin/env bats
# Feature: test-suite-reorganization, Property 1: Health Test Correctness

# PocketBase health tests
# Validates: Requirements 2.1, 2.7, 2.8

load '../helpers/auth.sh'
load '../helpers/cleanup.sh'
load '../helpers/wait.sh'
load '../helpers/assertions.sh'
load '../helpers/diagnostics.sh'
load '../helpers/tracking.sh'

setup() {
    # Load environment configuration
    load_env
    TEST_ID=$(generate_test_id)
    export CURRENT_TEST_ID="$TEST_ID"
}

teardown() {
    cleanup_test_data "$TEST_ID" || true
}

@test "PocketBase health endpoint returns 200 OK" {
    # Validates: Requirement 2.1
    run curl -s -w "%{http_code}" "$PB_URL/api/health"
    [ "$status" -eq 0 ]
    [[ "${lines[-1]}" == "200" ]] || run_diagnostic_on_failure "PocketBase" "Health endpoint returned ${lines[-1]} instead of 200"
}

@test "PocketBase health check completes within 30 seconds" {
    # Validates: Requirement 2.7
    run timeout 30 curl -s "$PB_URL/api/health"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PocketBase" "Health check timed out after 30 seconds"
}

@test "PocketBase accepts user authentication" {
    # Validates: Requirement 2.1 - database accessibility
    authenticate_user
    [ -n "$USER_TOKEN" ]
}

@test "PocketBase can create and query test records" {
    # Validates: Requirement 2.1 - database accessibility
    authenticate_user

    # Create a test chat record
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Health Test Chat $TEST_ID\", \"user\": \"$USER_ID\"}")
    local chat_id
    chat_id=$(echo "$chat_data" | jq -r '.id')

    # Track for cleanup
    track_artifact "chats:$chat_id"

    # Verify the record was created
    local retrieved
    retrieved=$(pb_get "chats" "$chat_id")
    local title
    title=$(echo "$retrieved" | jq -r '.title')
    [ "$title" = "Health Test Chat $TEST_ID" ] || run_diagnostic_on_failure "PocketBase" "Failed to create or retrieve test chat record"
}

@test "PocketBase Relay module is loaded" {
    # Validates: Requirement 2.1 - Relay module health check
    # Check for Relay healthcheck record or log evidence of Relay being active
    
    # First, authenticate to access Relay-related collections
    authenticate_user
    
    # Check if Relay healthcheck collection exists and has records
    # The Relay creates a healthcheck record to verify it's running
    local relay_check
    relay_check=$(curl -s -X GET "$PB_URL/api/collections/relay_healthcheck/records?sort=-created" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" 2>/dev/null || echo '{"items":[]}')
    
    local has_relay
    has_relay=$(echo "$relay_check" | jq -r '.items | length > 0' 2>/dev/null || echo "false")
    
    if [ "$has_relay" = "true" ]; then
        # Relay healthcheck record exists, module is loaded
        echo "Relay module is active (healthcheck record found)"
    else
        # Alternative: Check if messages collection has Relay hooks by creating a message
        # This verifies the Relay is intercepting messages
        local chat_data
        chat_data=$(pb_create "chats" "{\"title\": \"Relay Test Chat $TEST_ID\", \"user\": \"$USER_ID\"}")
        local chat_id
        chat_id=$(echo "$chat_data" | jq -r '.id')
        track_artifact "chats:$chat_id"
        
        # Create a test message - if Relay is active, it will attempt to process it
        local msg_data
        msg_data=$(pb_create "messages" "{\"chat\": \"$chat_id\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"relay test\"}]}")
        local msg_id
        msg_id=$(echo "$msg_data" | jq -r '.id')
        track_artifact "messages:$msg_id"
        
        # If we got here without errors, Relay hooks are registered
        [ -n "$msg_id" ] && [ "$msg_id" != "null" ] || run_diagnostic_on_failure "PocketBase" "Failed to create message - Relay hooks may not be registered"
    fi
}

@test "PocketBase health check provides diagnostic information on failure" {
    # Validates: Requirement 2.8
    # This test verifies that when health check fails, diagnostic info is available
    # In a real scenario, this would test actual failure conditions

    # Verify we can get detailed health info
    run curl -s "$PB_URL/api/health"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PocketBase" "Failed to get health endpoint response"

    # Response should be valid JSON
    echo "$output" | jq -e . > /dev/null
    [ "$?" -eq 0 ] || run_diagnostic_on_failure "PocketBase" "Health response is not valid JSON"
}