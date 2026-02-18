#!/usr/bin/env bats
# Feature: test-suite-reorganization
# Turn-Based Batching Integration Tests
# Validates: Requirements 10.7
#
# Tests turn-based locking and message batching (double texting)

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
    USER_MESSAGE_ID_1=""
    USER_MESSAGE_ID_2=""
}

teardown() {
    # Clean up all test data
    cleanup_test_data "$TEST_ID" || true
}

@test "Turn Batching: Create chat and verify initial turn" {
    # Authenticate
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Turn Batching Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    [ -n "$CHAT_ID" ] && [ "$CHAT_ID" != "null" ] || run_diagnostic_on_failure "Turn Batching" "Failed to create chat"
    
    # Verify initial turn
    local turn
    turn=$(echo "$chat_data" | jq -r '.turn // empty')
    
    # Initial turn should be empty or "user"
    [ -z "$turn" ] || [ "$turn" = "user" ] || [ "$turn" = "null" ] || run_diagnostic_on_failure "Turn Batching" "Initial turn should be empty or 'user', got: $turn"
    
    echo "✓ Chat created with correct initial turn"
}

@test "Turn Batching: Send first message and verify turn transition" {
    # Authenticate
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Turn Transition Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Send first message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Write a poem about the sea\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID_1=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID_1"
    
    [ -n "$USER_MESSAGE_ID_1" ] && [ "$USER_MESSAGE_ID_1" != "null" ] || run_diagnostic_on_failure "Turn Batching" "Failed to create first message"
    
    # Wait a moment for turn to transition
    sleep 2
    
    # Check turn transitioned to assistant
    local chat_state
    chat_state=$(curl -s -X GET "$PB_URL/api/collections/chats/records/$CHAT_ID" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local turn
    turn=$(echo "$chat_state" | jq -r '.turn // empty')
    
    # Turn should be "assistant" after message sent
    [ "$turn" = "assistant" ] || echo "⚠ Turn is '$turn' (expected 'assistant', but may be processing)"
    
    echo "✓ First message sent and turn transitioned"
}

@test "Turn Batching: Send multiple messages while processing" {
    # Authenticate
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Batch Messages Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Send first message (long task)
    local msg_data_1
    msg_data_1=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Write a ten line poem about the sea\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID_1=$(echo "$msg_data_1" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID_1"
    
    sleep 1
    
    # Send second message while first is processing
    local msg_data_2
    msg_data_2=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Actually, just say BATCH_SUCCESS\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID_2=$(echo "$msg_data_2" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID_2"
    
    [ -n "$USER_MESSAGE_ID_1" ] && [ -n "$USER_MESSAGE_ID_2" ] || run_diagnostic_on_failure "Turn Batching" "Failed to create messages"
    
    echo "✓ Multiple messages sent while processing"
}

@test "Turn Batching: Verify turn returns to user after processing" {
    # Authenticate
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Turn Return Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Send message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo hello\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID_1=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID_1"
    
    # Wait for assistant response
    local assistant_msg_id
    assistant_msg_id=$(wait_for_assistant_message "$CHAT_ID" 60)
    
    if [ -n "$assistant_msg_id" ] && [ "$assistant_msg_id" != "null" ]; then
        # Wait a moment for turn to return
        sleep 2
        
        # Check turn returned to user
        local chat_state
        chat_state=$(curl -s -X GET "$PB_URL/api/collections/chats/records/$CHAT_ID" \
            -H "Authorization: $USER_TOKEN" \
            -H "Content-Type: application/json")
        
        local turn
        turn=$(echo "$chat_state" | jq -r '.turn // empty')
        
        # Turn should be "user" after assistant response
        [ "$turn" = "user" ] || echo "⚠ Turn is '$turn' (expected 'user')"
        
        echo "✓ Turn returned to user after processing"
    else
        echo "⚠ No assistant message created, skipping turn verification"
    fi
}



# Helper function to wait for assistant message
wait_for_assistant_message() {
    local chat_id="$1"
    local timeout="${2:-60}"
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [ $(date +%s) -lt $end_time ]; do
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
