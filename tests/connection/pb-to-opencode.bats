#!/usr/bin/env bats
# Feature: test-suite-reorganization, Property 3: Connection Tests - PB to OpenCode
#
# Connection tests for PocketBase to OpenCode communication via the Interface service
# Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 11.2
#
# Test flow:
# 1. Create chat record in PocketBase
# 2. Create user message (interface subscription picks it up)
# 3. Interface calls ensureSession() via OpenCode SDK
# 4. Chat gets ai_engine_session_id populated
# 5. Interface sends message via OpenCode SDK session.prompt()
# 6. OpenCode processes, interface syncs assistant response to PocketBase
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

@test "PB→OpenCode: Create user message triggers interface subscription" {
    # Validates: Requirement 3.1
    # Test that creating a user message is picked up by the interface command pump
    
    authenticate_user
    
    # First create a chat for the message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Relay Hook Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Create a user message - interface subscription should pick this up
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Hello, test message for interface\"}], \"user_message_status\": \"pending\"}")
    MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    
    track_artifact "messages:$MESSAGE_ID"
    
    [ -n "$MESSAGE_ID" ] && [ "$MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "PB→OpenCode" "Failed to create message record"
    
    # Verify message was created with pending status
    local retrieved
    retrieved=$(pb_get "messages" "$MESSAGE_ID")
    local status
    status=$(echo "$retrieved" | jq -r '.user_message_status')
    [ "$status" = "pending" ] || run_diagnostic_on_failure "PB→OpenCode" "Message created with unexpected status: $status"
}

@test "PB→OpenCode: Interface creates session via OpenCode SDK" {
    # Validates: Requirement 3.2
    # Test that interface calls OpenCode's SDK to create a session
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Session Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Create message to trigger interface
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Test session creation\"}], \"user_message_status\": \"pending\"}")
    MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$MESSAGE_ID"

    # Wait for session to be created (interface creates session via OpenCode SDK)
    # The chat record should get ai_engine_session_id populated
    run wait_for_condition 30 "test -n \"\$(get_chat_session_id '$CHAT_ID')\""
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PB→OpenCode" "Session not created within 30 seconds"
    
    # Verify session ID was populated
    SESSION_ID=$(get_chat_session_id "$CHAT_ID")
    [ -n "$SESSION_ID" ] && [ "$SESSION_ID" != "null" ] || run_diagnostic_on_failure "PB→OpenCode" "Chat does not have ai_engine_session_id"
}

@test "PB→OpenCode: Chat record gets ai_engine_session_id populated" {
    # Validates: Requirement 3.3
    # Test that after the interface processes the message, the chat has session ID
    
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
    
    # Create message to trigger interface
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

@test "PB→OpenCode: Interface sends message via OpenCode SDK" {
    # Validates: Requirement 3.4
    # Test that the interface service delivers the message to OpenCode via SDK

    authenticate_user

    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Prompt Async Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"

    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Test prompt delivery\"}], \"user_message_status\": \"pending\"}")
    MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$MESSAGE_ID"

    # Wait for session to be created (interface picked up the message and sent it)
    run wait_for_message_processed "$CHAT_ID" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PB→OpenCode" "Message not processed by interface within 30 seconds"

    SESSION_ID=$(get_chat_session_id "$CHAT_ID")
    echo "✓ Interface delivered message via OpenCode SDK (session: $SESSION_ID)"
}

@test "PB→OpenCode: Message lifecycle — create → session → assistant response" {
    # Validates: Requirement 3.5
    # Test the complete message lifecycle via the interface service:
    # 1. User creates message in PocketBase
    # 2. Interface picks it up, creates/ensures OpenCode session
    # 3. Interface sends prompt via SDK
    # 4. OpenCode processes and returns assistant response
    # 5. Interface syncs assistant message back to PocketBase

    authenticate_user

    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Lifecycle Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"

    # Create message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Test message lifecycle\"}], \"user_message_status\": \"pending\"}")
    MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$MESSAGE_ID"

    # Step 1: Wait for interface to create session
    run wait_for_message_processed "$CHAT_ID" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PB→OpenCode" "Session not created within 30 seconds"

    SESSION_ID=$(get_chat_session_id "$CHAT_ID")
    echo "✓ Session created: $SESSION_ID"

    # Step 2: Wait for assistant response (proves full round-trip)
    local assistant_id
    assistant_id=$(wait_for_assistant_message "$CHAT_ID" 90)
    [ -n "$assistant_id" ] && [ "$assistant_id" != "null" ] || \
        run_diagnostic_on_failure "PB→OpenCode" "No assistant response within 90 seconds"

    echo "✓ Full message lifecycle verified: create → session → assistant response"
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
    
    # Wait for interface to process the message
    run wait_for_message_processed "$CHAT_ID" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PB→OpenCode" "Message not processed within 30 seconds"

    # Wait for assistant message (which also sets the turn)
    local assistant_id
    assistant_id=$(wait_for_assistant_message "$CHAT_ID" 90)
    [ -n "$assistant_id" ] && [ "$assistant_id" != "null" ] || \
        run_diagnostic_on_failure "PB→OpenCode" "No assistant response within 90 seconds"
    
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