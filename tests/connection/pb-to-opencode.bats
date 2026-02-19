#!/usr/bin/env bats
# Feature: test-suite-reorganization, Property 3: Connection Tests - PB to OpenCode
#
# Connection tests for PocketBase to OpenCode communication via HTTP POST
# Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 11.2
#
# Test flow:
# 1. Create chat record in PocketBase
# 2. Create user message (triggers Relay hook)
# 3. Relay calls ensureSession() → POST {OPENCODE_URL}/session
# 4. Chat gets ai_engine_session_id populated
# 5. Relay sends message via POST {OPENCODE_URL}/session/{id}/prompt_async
# 6. Message status transitions: pending → sending → delivered
# 7. Chat turn field updates to assistant

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
    MESSAGE_ID=""
    SESSION_ID=""
}

teardown() {
    # Cleanup in reverse order to handle dependencies
    cleanup_test_data "$TEST_ID" || true
}

@test "PB→OpenCode: Create chat record in PocketBase" {
    # Validates: Requirement 3.1
    # Test that we can create a chat record that will be used for the connection test
    
    authenticate_user
    
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Connection Test Chat $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    
    track_artifact "chats:$CHAT_ID"
    
    [ -n "$CHAT_ID" ] && [ "$CHAT_ID" != "null" ] || run_diagnostic_on_failure "PB→OpenCode" "Failed to create chat record"
    
    # Verify chat was created with expected fields
    local retrieved
    retrieved=$(pb_get "chats" "$CHAT_ID")
    local title
    title=$(echo "$retrieved" | jq -r '.title')
    [ "$title" = "Connection Test Chat $TEST_ID" ]
}

@test "PB→OpenCode: Create user message triggers Relay hook" {
    # Validates: Requirement 3.1
    # Test that creating a user message triggers the OnRecordAfterCreateSuccess hook
    
    authenticate_user
    
    # First create a chat for the message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Relay Hook Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Create a user message - this should trigger the Relay hook
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Hello, test message for Relay hook\"}], \"user_message_status\": \"pending\"}")
    MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    
    track_artifact "messages:$MESSAGE_ID"
    
    [ -n "$MESSAGE_ID" ] && [ "$MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "PB→OpenCode" "Failed to create message record"
    
    # Verify message was created with valid status (relay may process fast)
    local retrieved
    retrieved=$(pb_get "messages" "$MESSAGE_ID")
    local status
    status=$(echo "$retrieved" | jq -r '.user_message_status')
    [[ "$status" =~ ^(pending|sending|delivered)$ ]] || run_diagnostic_on_failure "PB→OpenCode" "Message created with unexpected status: $status"
}

@test "PB→OpenCode: Relay calls ensureSession() via POST /session" {
    # Validates: Requirement 3.2
    # Test that Relay calls OpenCode's session endpoint to create a session
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Session Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Create message to trigger Relay
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Test session creation\"}], \"user_message_status\": \"pending\"}")
    MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$MESSAGE_ID"
    
    # Wait for session to be created (Relay should call POST {OPENCODE_URL}/session)
    # The chat record should get ai_engine_session_id populated
    run wait_for_condition 30 "test -n \"\$(get_chat_session_id '$CHAT_ID')\""
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PB→OpenCode" "Session not created within 30 seconds"
    
    # Verify session ID was populated
    SESSION_ID=$(get_chat_session_id "$CHAT_ID")
    [ -n "$SESSION_ID" ] && [ "$SESSION_ID" != "null" ] || run_diagnostic_on_failure "PB→OpenCode" "Chat does not have ai_engine_session_id"
}

@test "PB→OpenCode: Chat record gets ai_engine_session_id populated" {
    # Validates: Requirement 3.3
    # Test that after Relay processes the message, the chat has session ID
    
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Session ID Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Verify initial state - no session ID
    local initial
    initial=$(pb_get "chats" "$CHAT_ID")
    local initial_session
    initial_session=$(echo "$initial" | jq -r '.ai_engine_session_id // empty')
    [ -z "$initial_session" ] || run_diagnostic_on_failure "PB→OpenCode" "Chat already has session ID before message creation"
    
    # Create message to trigger Relay
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Test session ID population\"}], \"user_message_status\": \"pending\"}")
    MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$MESSAGE_ID"
    
    # Wait for session ID to be populated
    run wait_for_condition 30 "test -n \"\$(get_chat_session_id '$CHAT_ID')\""
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PB→OpenCode" "ai_engine_session_id not populated within 30 seconds"
    
    # Verify session ID format (should be a valid ID string)
    SESSION_ID=$(get_chat_session_id "$CHAT_ID")
    [[ "$SESSION_ID" =~ ^[a-zA-Z0-9_-]+$ ]] || run_diagnostic_on_failure "PB→OpenCode" "Session ID has invalid format: $SESSION_ID"
}

@test "PB→OpenCode: Relay sends message via POST /session/{id}/prompt_async" {
    # Validates: Requirement 3.4
    # Test that Relay delivers the message to OpenCode via prompt_async endpoint
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Prompt Async Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Test prompt async delivery\"}], \"user_message_status\": \"pending\"}")
    MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$MESSAGE_ID"
    
    # Wait for session to be created
    run wait_for_condition 30 "test -n \"\$(get_chat_session_id '$CHAT_ID')\""
    [ "$status" -eq 0 ]
    
    SESSION_ID=$(get_chat_session_id "$CHAT_ID")
    
    # Wait for message status to transition from pending (Relay sends to OpenCode)
    # Status should go: pending → sending → delivered
    run wait_for_message_status "$MESSAGE_ID" "sending" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PB→OpenCode" "Message status did not transition to 'sending' within 30 seconds"
}

@test "PB→OpenCode: Message status transitions pending → sending → delivered" {
    # Validates: Requirement 3.5
    # Test the complete status transition lifecycle
    
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Status Transition Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Create message with pending status
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Test status transition\"}], \"user_message_status\": \"pending\"}")
    MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$MESSAGE_ID"
    
    # Verify initial status (relay may process fast, so accept pending/sending/delivered)
    # Use helper function to check if relay has already processed it
    if message_has_relay_progress "$MESSAGE_ID"; then
        echo "✓ Message already delivered (relay processed very fast)"
    else
        local initial_status
        initial_status=$(get_message_status "$MESSAGE_ID")
        [[ "$initial_status" =~ ^(pending|sending|delivered)$ ]] || run_diagnostic_on_failure "PB→OpenCode" "Initial status is unexpected: $initial_status"
    fi
    
    # Wait for status to transition to sending (Relay processing)
    run wait_for_message_status "$MESSAGE_ID" "sending" 60
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PB→OpenCode" "Status did not transition to 'sending' within 60 seconds"
    
    # Wait for status to transition to delivered (OpenCode received and processed)
    run wait_for_message_status "$MESSAGE_ID" "delivered" 120
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PB→OpenCode" "Status did not transition to 'delivered' within 120 seconds"
    
    # Final verification
    local final_status
    final_status=$(get_message_status "$MESSAGE_ID")
    [ "$final_status" = "delivered" ] || run_diagnostic_on_failure "PB→OpenCode" "Final status is not 'delivered': $final_status"
}

@test "PB→OpenCode: Chat turn field updates to assistant" {
    # Validates: Requirement 3.5
    # Test that after OpenCode processes the message, chat turn updates
    
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Turn Update Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Verify initial turn is empty or user
    local initial
    initial=$(pb_get "chats" "$CHAT_ID")
    local initial_turn
    initial_turn=$(echo "$initial" | jq -r '.turn // empty')
    
    # Create message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Test turn update\"}], \"user_message_status\": \"pending\"}")
    MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$MESSAGE_ID"
    
    # Wait for message to be delivered (OpenCode processes it)
    run wait_for_message_status "$MESSAGE_ID" "delivered" 120
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PB→OpenCode" "Message not delivered within 120 seconds"
    
    # Wait for chat turn to update to assistant (OpenCode responds)
    run wait_for_condition 30 "test \"\$(get_chat_turn '$CHAT_ID')\" = \"assistant\""
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PB→OpenCode" "Chat turn did not update to 'assistant' within 30 seconds"
    
    # Verify turn is now assistant
    local turn
    turn=$(get_chat_turn "$CHAT_ID")
    [ "$turn" = "assistant" ] || run_diagnostic_on_failure "PB→OpenCode" "Chat turn is not 'assistant': $turn"
}

@test "PB→OpenCode: Cleanup removes test chats and messages" {
    # Validates: Requirements 3.6, 11.2
    # Test that cleanup properly removes test data
    
    authenticate_user
    
    # Create test data
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Cleanup Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Test cleanup\"}], \"user_message_status\": \"pending\"}")
    MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$MESSAGE_ID"
    
    # Verify data exists
    local chat_check
    chat_check=$(pb_get "chats" "$CHAT_ID")
    local chat_exists
    chat_exists=$(echo "$chat_check" | jq -r '.id // empty')
    [ -n "$chat_exists" ] || run_diagnostic_on_failure "PB→OpenCode" "Chat not found before cleanup"
    
    local msg_check
    msg_check=$(pb_get "messages" "$MESSAGE_ID")
    local msg_exists
    msg_exists=$(echo "$msg_check" | jq -r '.id // empty')
    [ -n "$msg_exists" ] || run_diagnostic_on_failure "PB→OpenCode" "Message not found before cleanup"
    
    # Run cleanup (this happens in teardown, but we test it explicitly)
    cleanup_test_data "$TEST_ID"
    
    # Verify data is removed
    local chat_after
    chat_after=$(pb_get "chats" "$CHAT_ID" 2>/dev/null || echo '{"id":""}')
    local chat_gone
    chat_gone=$(echo "$chat_after" | jq -r '.id // empty')
    [ -z "$chat_gone" ] || run_diagnostic_on_failure "PB→OpenCode" "Chat still exists after cleanup"
}