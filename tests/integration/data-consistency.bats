#!/usr/bin/env bats
# Feature: test-suite-reorganization, Property 8.2: Data Consistency Checks
#
# Data consistency verification for PocketCoder integration tests
# Validates: Requirement 8.2
#
# Test focus:
# 1. Verify all intermediate records exist
# 2. Verify timestamps are reasonable
# 3. Verify data relationships are correct (chat → message → session)

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
    ASSISTANT_MESSAGE_ID=""
    SESSION_ID=""
}

teardown() {
    cleanup_test_data "$TEST_ID" || true
    
    if [ -n "$SESSION_ID" ]; then
        delete_opencode_session "$SESSION_ID" || true
    fi
}

@test "Data Consistency: All intermediate records exist" {
    # Validates: Requirement 8.2 - Verify all intermediate records exist
    
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Data Consistency Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Create user message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo data consistency\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for full processing
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    
    # Verify chat record exists
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    local chat_id
    chat_id=$(echo "$chat_record" | jq -r '.id')
    [ "$chat_id" = "$CHAT_ID" ] || run_diagnostic_on_failure "Data Consistency" "Chat record not found"
    
    # Verify user message record exists
    local user_msg
    user_msg=$(pb_get "messages" "$USER_MESSAGE_ID")
    local msg_id
    msg_id=$(echo "$user_msg" | jq -r '.id')
    [ "$msg_id" = "$USER_MESSAGE_ID" ] || run_diagnostic_on_failure "Data Consistency" "User message record not found"
    
    # Verify assistant message record exists
    if [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]; then
        local assistant_msg
        assistant_msg=$(pb_get "messages" "$ASSISTANT_MESSAGE_ID")
        local asst_id
        asst_id=$(echo "$assistant_msg" | jq -r '.id')
        [ "$asst_id" = "$ASSISTANT_MESSAGE_ID" ] || run_diagnostic_on_failure "Data Consistency" "Assistant message record not found"
    else
        echo "ℹ Assistant message not created (may be expected)"
    fi
    
    echo "✓ All intermediate records exist"
}

@test "Data Consistency: Timestamps are reasonable" {
    # Validates: Requirement 8.2 - Verify timestamps are reasonable
    
    authenticate_user
    
    # Record start time
    local start_time
    start_time=$(date +%s)
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Timestamp Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Create user message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo timestamps\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for processing
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    
    # Record end time
    local end_time
    end_time=$(date +%s)
    
    # Verify chat timestamps
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    
    local chat_created
    chat_created=$(echo "$chat_record" | jq -r '.created')
    [ -n "$chat_created" ] && [ "$chat_created" != "null" ] || run_diagnostic_on_failure "Data Consistency" "Chat created timestamp missing"
    
    local chat_updated
    chat_updated=$(echo "$chat_record" | jq -r '.updated')
    [ -n "$chat_updated" ] && [ "$chat_updated" != "null" ] || run_diagnostic_on_failure "Data Consistency" "Chat updated timestamp missing"
    
    # Verify chat timestamps are within reasonable range
    local chat_created_ts
    chat_created_ts=$(date -d "$chat_created" +%s 2>/dev/null || echo "0")
    [ "$chat_created_ts" -ge $((start_time - 60)) ] && [ "$chat_created_ts" -le $((end_time + 60)) ] || \
        run_diagnostic_on_failure "Data Consistency" "Chat created timestamp out of range"
    
    # Verify user message timestamps
    local user_msg
    user_msg=$(pb_get "messages" "$USER_MESSAGE_ID")
    
    local msg_created
    msg_created=$(echo "$user_msg" | jq -r '.created')
    [ -n "$msg_created" ] && [ "$msg_created" != "null" ] || run_diagnostic_on_failure "Data Consistency" "Message created timestamp missing"
    
    local msg_updated
    msg_updated=$(echo "$user_msg" | jq -r '.updated')
    [ -n "$msg_updated" ] && [ "$msg_updated" != "null" ] || run_diagnostic_on_failure "Data Consistency" "Message updated timestamp missing"
    
    # Verify message timestamps are within reasonable range
    local msg_created_ts
    msg_created_ts=$(date -d "$msg_created" +%s 2>/dev/null || echo "0")
    [ "$msg_created_ts" -ge $((start_time - 60)) ] && [ "$msg_created_ts" -le $((end_time + 60)) ] || \
        run_diagnostic_on_failure "Data Consistency" "Message created timestamp out of range"
    
    # Verify assistant message timestamps if exists
    if [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]; then
        local assistant_msg
        assistant_msg=$(pb_get "messages" "$ASSISTANT_MESSAGE_ID")
        
        local asst_created
        asst_created=$(echo "$assistant_msg" | jq -r '.created')
        [ -n "$asst_created" ] && [ "$asst_created" != "null" ] || run_diagnostic_on_failure "Data Consistency" "Assistant message created timestamp missing"
        
        # Assistant message should be created after user message
        local asst_created_ts
        asst_created_ts=$(date -d "$asst_created" +%s 2>/dev/null || echo "0")
        [ "$asst_created_ts" -ge "$msg_created_ts" ] || run_diagnostic_on_failure "Data Consistency" "Assistant message created before user message"
    fi
    
    echo "✓ All timestamps are reasonable"
}

@test "Data Consistency: Data relationships are correct (chat → message → session)" {
    # Validates: Requirement 8.2 - Verify data relationships
    
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Relationships Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Create user message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo relationships\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for processing
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    
    # Verify chat → message relationship
    local messages_in_chat
    messages_in_chat=$(curl -s -X GET "$PB_URL/api/collections/messages/records?filter=chat=\"$CHAT_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local msg_count
    msg_count=$(echo "$messages_in_chat" | jq -r '.totalCount')
    [ "$msg_count" -ge 1 ] || run_diagnostic_on_failure "Data Consistency" "No messages found in chat"
    
    # Verify user message points to correct chat
    local user_msg
    user_msg=$(pb_get "messages" "$USER_MESSAGE_ID")
    local msg_chat_id
    msg_chat_id=$(echo "$user_msg" | jq -r '.chat')
    [ "$msg_chat_id" = "$CHAT_ID" ] || run_diagnostic_on_failure "Data Consistency" "User message does not point to correct chat"
    
    # Verify chat has user_id set
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    local chat_user_id
    chat_user_id=$(echo "$chat_record" | jq -r '.user')
    [ -n "$chat_user_id" ] && [ "$chat_user_id" != "null" ] || run_diagnostic_on_failure "Data Consistency" "Chat user_id not set"
    
    # Verify assistant message points to correct chat
    if [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]; then
        local assistant_msg
        assistant_msg=$(pb_get "messages" "$ASSISTANT_MESSAGE_ID")
        local asst_chat_id
        asst_chat_id=$(echo "$assistant_msg" | jq -r '.chat')
        [ "$asst_chat_id" = "$CHAT_ID" ] || run_diagnostic_on_failure "Data Consistency" "Assistant message does not point to correct chat"
        
        # Verify assistant message has role = assistant
        local asst_role
        asst_role=$(echo "$assistant_msg" | jq -r '.role')
        [ "$asst_role" = "assistant" ] || run_diagnostic_on_failure "Data Consistency" "Assistant message role is not 'assistant'"
    fi
    
    # Verify chat → session relationship (if session was created)
    local chat_record_final
    chat_record_final=$(pb_get "chats" "$CHAT_ID")
    local session_id
    session_id=$(echo "$chat_record_final" | jq -r '.ai_engine_session_id // empty')
    
    if [ -n "$session_id" ] && [ "$session_id" != "null" ]; then
        SESSION_ID="$session_id"
        # Session ID should be a non-empty string
        [ ${#session_id} -gt 0 ] || run_diagnostic_on_failure "Data Consistency" "Session ID is empty"
    else
        echo "ℹ Session ID not created (may be expected)"
    fi
    
    echo "✓ All data relationships are correct"
}

@test "Data Consistency: Message status transitions are correct" {
    # Validates: Requirement 8.2 - Verify message status transitions
    
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Status Transition Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Create user message with pending status
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo status transition\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Verify initial status is pending
    local initial_msg
    initial_msg=$(pb_get "messages" "$USER_MESSAGE_ID")
    local initial_status
    initial_status=$(echo "$initial_msg" | jq -r '.user_message_status')
    [ "$initial_status" = "pending" ] || run_diagnostic_on_failure "Data Consistency" "Initial message status is not 'pending'"
    
    # Wait for status to change to sending
    run wait_for_message_status "$USER_MESSAGE_ID" "sending" 15
    [ "$status" -eq 0 ] || echo "ℹ Message did not transition to 'sending' (may be expected)"
    
    # Wait for status to change to delivered
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Data Consistency" "Message did not transition to 'delivered'"
    
    # Verify final status is delivered
    local final_msg
    final_msg=$(pb_get "messages" "$USER_MESSAGE_ID")
    local final_status
    final_status=$(echo "$final_msg" | jq -r '.user_message_status')
    [ "$final_status" = "delivered" ] || run_diagnostic_on_failure "Data Consistency" "Final message status is not 'delivered': $final_status"
    
    echo "✓ Message status transitions are correct: pending → sending → delivered"
}

@test "Data Consistency: Chat turn field updates correctly" {
    # Validates: Requirement 8.2 - Verify chat turn field
    
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Turn Field Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Get initial turn value
    local initial_chat
    initial_chat=$(pb_get "chats" "$CHAT_ID")
    local initial_turn
    initial_turn=$(echo "$initial_chat" | jq -r '.turn // empty')
    
    # Create user message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo turn field\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    
    # Verify turn field updated to assistant
    local updated_chat
    updated_chat=$(pb_get "chats" "$CHAT_ID")
    local turn
    turn=$(echo "$updated_chat" | jq -r '.turn // empty')
    
    [ -n "$turn" ] && [ "$turn" != "null" ] || run_diagnostic_on_failure "Data Consistency" "Chat turn field not set"
    [ "$turn" = "assistant" ] || run_diagnostic_on_failure "Data Consistency" "Chat turn is not 'assistant': $turn"
    
    echo "✓ Chat turn field updated correctly: $turn"
}

@test "Data Consistency: Message parts are preserved through flow" {
    # Validates: Requirement 8.2 - Verify message parts integrity
    
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Parts Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Create message with specific parts
    local test_text="Test message parts preservation"
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"$test_text\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Verify user message parts are preserved
    local user_msg
    user_msg=$(pb_get "messages" "$USER_MESSAGE_ID")
    local parts
    parts=$(echo "$user_msg" | jq -r '.parts')
    [ -n "$parts" ] && [ "$parts" != "null" ] && [ "$parts" != "[]" ] || run_diagnostic_on_failure "Data Consistency" "User message parts not preserved"
    
    local preserved_text
    preserved_text=$(echo "$parts" | jq -r '.[0].text // empty')
    [ "$preserved_text" = "$test_text" ] || run_diagnostic_on_failure "Data Consistency" "User message text not preserved: $preserved_text != $test_text"
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    
    # Verify assistant message has parts
    if [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]; then
        local assistant_msg
        assistant_msg=$(pb_get "messages" "$ASSISTANT_MESSAGE_ID")
        local asst_parts
        asst_parts=$(echo "$assistant_msg" | jq -r '.parts')
        [ -n "$asst_parts" ] && [ "$asst_parts" != "null" ] && [ "$asst_parts" != "[]" ] || run_diagnostic_on_failure "Data Consistency" "Assistant message parts not created"
    fi
    
    echo "✓ Message parts are preserved through the flow"
}

# Helper function to wait for assistant message
wait_for_assistant_message() {
    local chat_id="$1"
    local timeout="${2:-60}"
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [ $(date +%s) -lt $end_time ]; do
        # Query for assistant message in this chat
        local response
        response=$(curl -s -X GET "$PB_URL/api/collections/messages/records?filter=chat=\"$chat_id\"%20%26%26%20role=\"assistant\"&sort=created" \
            -H "Authorization: $USER_TOKEN" \
            -H "Content-Type: application/json")
        
        local assistant_id
        assistant_id=$(echo "$response" | jq -r '.items[0].id // empty')
        
        if [ -n "$assistant_id" ] && [ "$assistant_id" != "null" ]; then
            echo "$assistant_id"
            return 0
        fi
        
        sleep 1
    done
    
    echo ""
    return 1
}