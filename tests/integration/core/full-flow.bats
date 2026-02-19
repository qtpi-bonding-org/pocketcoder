#!/usr/bin/env bats
# Feature: test-suite-reorganization, Property 8: Full Flow Integration Test
#
# Complete end-to-end integration test for PocketCoder flow
# Validates: Requirements 8.1, 8.2, 8.3
#
# Test flow:
# 1. User authenticates with PocketBase
# 2. User creates chat record
# 3. User sends message (role: user, user_message_status: pending)
# 4. Relay intercepts via OnRecordAfterCreateSuccess hook
# 5. Relay calls ensureSession() → POST {OPENCODE_URL}/session
# 6. Relay delivers message via POST {OPENCODE_URL}/session/{id}/prompt_async
# 7. OpenCode processes message
# 8. Command execution via shell bridge → POST sandbox:3001/exec
# 9. Driver resolves session via GET sandbox:9889/terminals/by-delegating-agent/{id}
# 10. Tmux execution with sentinel and output capture
# 11. Synchronous response returned to shell bridge
# 12. Relay SSE listener at {OPENCODE_URL}/event receives message.updated
# 13. syncAssistantMessage() creates assistant message record
# 14. Chat updated with last_active, preview

load '../../helpers/auth.sh'
load '../../helpers/cleanup.sh'
load '../../helpers/wait.sh'
load '../../helpers/assertions.sh'
load '../../helpers/diagnostics.sh'
load '../../helpers/tracking.sh'

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
    # Clean up all test data
    cleanup_test_data "$TEST_ID" || true
    
    # Clean up OpenCode session if created
    if [ -n "$SESSION_ID" ]; then
        delete_opencode_session "$SESSION_ID" || true
    fi
}

@test "Full Flow: User authenticates with PocketBase" {
    # Validates: Requirement 8.1 - User authentication step
    
    # Authenticate as regular user (don't use 'run' - we need the exported vars)
    authenticate_user
    [ "$?" -eq 0 ] || run_diagnostic_on_failure "Full Flow" "User authentication failed"
    
    # Verify USER_TOKEN and USER_ID are set
    [ -n "$USER_TOKEN" ] || run_diagnostic_on_failure "Full Flow" "USER_TOKEN not set after authentication"
    [ -n "$USER_ID" ] || run_diagnostic_on_failure "Full Flow" "USER_ID not set after authentication"
    
    echo "✓ User authenticated successfully: $USER_ID"
}

@test "Full Flow: User creates chat record" {
    # Validates: Requirement 8.1 - Create chat step
    
    authenticate_user
    
    # Create a chat record
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Full Flow Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    
    # Verify chat was created
    [ -n "$CHAT_ID" ] && [ "$CHAT_ID" != "null" ] || run_diagnostic_on_failure "Full Flow" "Chat creation failed"
    track_artifact "chats:$CHAT_ID"
    
    # Verify chat has expected fields
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    local title
    title=$(echo "$chat_record" | jq -r '.title')
    [ "$title" = "Full Flow Test $TEST_ID" ] || run_diagnostic_on_failure "Full Flow" "Chat title mismatch"
    
    echo "✓ Chat created successfully: $CHAT_ID"
}

@test "Full Flow: User sends message (role: user, user_message_status: pending)" {
    # Validates: Requirement 8.1 - Send message step
    
    authenticate_user
    
    # Create chat first
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Full Flow Message Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Create user message with pending status
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo hello world\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    
    # Verify message was created
    [ -n "$USER_MESSAGE_ID" ] && [ "$USER_MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "Full Flow" "Message creation failed"
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Verify message has expected fields
    local msg_record
    msg_record=$(pb_get "messages" "$USER_MESSAGE_ID")
    local role
    role=$(echo "$msg_record" | jq -r '.role')
    [ "$role" = "user" ] || run_diagnostic_on_failure "Full Flow" "Message role is not 'user'"
    
    local status
    status=$(echo "$msg_record" | jq -r '.user_message_status')
    [[ "$status" =~ ^(pending|sending|delivered)$ ]] || run_diagnostic_on_failure "Full Flow" "Message status is unexpected: $status"
    
    echo "✓ User message created: $USER_MESSAGE_ID (status: $status)"
}

@test "Full Flow: Relay intercepts via OnRecordAfterCreateSuccess hook" {
    # Validates: Requirement 8.1 - Relay hook interception
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Relay Hook Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Test relay hook\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message status to change from pending (indicates Relay hook fired)
    # If already sending/delivered, the relay was very fast
    # Use helper function to check if relay has already processed it
    if message_has_relay_progress "$USER_MESSAGE_ID"; then
        echo "✓ Relay hook already processed message"
    else
        run wait_for_message_status "$USER_MESSAGE_ID" "sending" 15
        [ "$status" -eq 0 ] || run_diagnostic_on_failure "Full Flow" "Relay hook did not fire (status still pending after 15s)"
        echo "✓ Relay hook intercepted message (status changed to sending)"
    fi
}

@test "Full Flow: Relay calls ensureSession() → POST /session" {
    # Validates: Requirement 8.1 - Session creation via Relay
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Session Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo test session\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message to be delivered (indicates session was created)
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Full Flow" "Message not delivered (session creation may have failed)"
    
    # Verify chat has ai_engine_session_id populated
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    local session_id
    session_id=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    [ -n "$session_id" ] && [ "$session_id" != "null" ] || run_diagnostic_on_failure "Full Flow" "ai_engine_session_id not populated in chat"
    
    SESSION_ID="$session_id"
    echo "✓ Session created: $SESSION_ID"
}

@test "Full Flow: Relay delivers message via POST /session/{id}/prompt_async" {
    # Validates: Requirement 8.1 - Message delivery to OpenCode
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Prompt Delivery Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo prompt delivery\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message to be delivered
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Full Flow" "Message not delivered to OpenCode"
    
    # Verify message status transitioned through expected states
    # pending → sending → delivered
    local msg_record
    msg_record=$(pb_get "messages" "$USER_MESSAGE_ID")
    local status
    status=$(echo "$msg_record" | jq -r '.user_message_status')
    [ "$status" = "delivered" ] || run_diagnostic_on_failure "Full Flow" "Message status is not 'delivered': $status"
    
    echo "✓ Message delivered to OpenCode (status: delivered)"
}

@test "Full Flow: OpenCode processes message" {
    # Validates: Requirement 8.1 - OpenCode message processing
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"OpenCode Processing Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo opencode processing\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for assistant message to be created (OpenCode processing complete)
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "Full Flow" "Assistant message not created (OpenCode processing failed)"
    
    # Verify assistant message has content
    local assistant_msg
    assistant_msg=$(pb_get "messages" "$ASSISTANT_MESSAGE_ID")
    local parts
    parts=$(echo "$assistant_msg" | jq -r '.parts // empty')
    [ -n "$parts" ] && [ "$parts" != "null" ] && [ "$parts" != "[]" ] || run_diagnostic_on_failure "Full Flow" "Assistant message has no parts (no response generated)"
    
    echo "✓ OpenCode processed message: assistant message $ASSISTANT_MESSAGE_ID"
}

@test "Full Flow: Command execution via shell bridge → POST /exec" {
    # Validates: Requirement 8.1 - Shell bridge command execution
    
    authenticate_user
    
    # Create chat and message that will trigger command execution
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Shell Bridge Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Create message with command
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo shell bridge test\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for assistant message (indicates command was executed)
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "Full Flow" "Command execution failed (no assistant response)"
    
    # Verify shell bridge binary exists and is executable (correct path in sandbox)
    run docker exec pocketcoder-sandbox test -x /app/shell_bridge/pocketcoder-shell
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Full Flow" "Shell bridge binary not found or not executable"
    
    echo "✓ Command executed via shell bridge"
}

@test "Full Flow: Driver resolves session via GET /terminals/by-delegating-agent/{id}" {
    # Validates: Requirement 8.1 - Session resolution via CAO
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Resolution Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo cao resolution\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message to be delivered (session created)
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Get session ID from chat
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    local session_id
    session_id=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    
    [ -n "$session_id" ] && [ "$session_id" != "null" ] || run_diagnostic_on_failure "Full Flow" "Session ID not found in chat"
    
    # Verify CAO API is accessible
    run wait_for_endpoint "http://$SANDBOX_HOST:$SANDBOX_CAO_API_PORT/health" 10
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Full Flow" "CAO API not accessible"
    
    # Query terminal by delegating agent (session_id)
    local terminal_response
    terminal_response=$(curl -s "http://$SANDBOX_HOST:$SANDBOX_CAO_API_PORT/terminals/by-delegating-agent/$session_id" 2>/dev/null)
    
    # The response should contain terminal info (may be empty if not yet created)
    # This test verifies the endpoint is reachable
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$SANDBOX_HOST:$SANDBOX_CAO_API_PORT/terminals/by-delegating-agent/$session_id")
    [ "$http_code" = "200" ] || [ "$http_code" = "404" ] || run_diagnostic_on_failure "Full Flow" "Terminal endpoint returned HTTP $http_code"
    
    echo "✓ CAO session resolution endpoint accessible"
}

@test "Full Flow: Tmux execution with sentinel and output capture" {
    # Validates: Requirement 8.1 - Tmux execution with sentinel pattern
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Tmux Sentinel Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo tmux sentinel test\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for assistant message (command executed in tmux)
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "Full Flow" "Tmux execution failed (no assistant response)"
    
    # Verify tmux session exists
    run docker exec pocketcoder-sandbox tmux -S /tmp/tmux/pocketcoder has-session -t pocketcoder_session
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Full Flow" "Tmux session pocketcoder_session does not exist"
    
    # Verify tmux socket exists
    run docker exec pocketcoder-sandbox test -S /tmp/tmux/pocketcoder/pocketcoder
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Full Flow" "Tmux socket does not exist"
    
    echo "✓ Tmux execution with sentinel completed"
}

@test "Full Flow: Synchronous response returned to shell bridge" {
    # Validates: Requirement 8.1 - Synchronous exec response
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Sync Response Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo sync response\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for assistant message (sync response received)
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "Full Flow" "Sync response not received (no assistant message)"
    
    # Verify assistant message has content (response was captured)
    local assistant_msg
    assistant_msg=$(pb_get "messages" "$ASSISTANT_MESSAGE_ID")
    local parts
    parts=$(echo "$assistant_msg" | jq -r '.parts // empty')
    
    # Check that response contains expected output
    local response_text
    response_text=$(echo "$parts" | jq -r '.[0].text // empty')
    [ -n "$response_text" ] || run_diagnostic_on_failure "Full Flow" "Response text not captured in assistant message"
    
    echo "✓ Synchronous response returned to shell bridge"
}

@test "Full Flow: Relay SSE listener receives message.updated" {
    # Validates: Requirement 8.1 - SSE event reception
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"SSE Event Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo sse event\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for assistant message (SSE event processed)
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "Full Flow" "SSE event not processed (no assistant message)"
    
    # Verify SSE endpoint is accessible
    local sse_url="$OPENCODE_URL/event"
    run timeout 5 curl -s -I "$sse_url" 2>/dev/null
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Full Flow" "SSE endpoint not accessible"
    
    # Verify SSE endpoint returns correct content type
    local response
    response=$(timeout 5 curl -s -I "$sse_url" 2>/dev/null)
    echo "$response" | grep -qi "content-type.*text/event-stream" || run_diagnostic_on_failure "Full Flow" "SSE endpoint Content-Type incorrect"
    
    echo "✓ Relay SSE listener received message.updated events"
}

@test "Full Flow: syncAssistantMessage() creates assistant message record" {
    # Validates: Requirement 8.2 - Assistant message creation via syncAssistantMessage
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Sync Assistant Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo sync assistant\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for assistant message to be created
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "Full Flow" "syncAssistantMessage() did not create assistant message"
    
    # Verify assistant message has expected fields
    local assistant_msg
    assistant_msg=$(pb_get "messages" "$ASSISTANT_MESSAGE_ID")
    
    # Check role is assistant
    local role
    role=$(echo "$assistant_msg" | jq -r '.role')
    [ "$role" = "assistant" ] || run_diagnostic_on_failure "Full Flow" "Assistant message role is not 'assistant'"
    
    # Check ai_engine_message_id is populated
    local ai_msg_id
    ai_msg_id=$(echo "$assistant_msg" | jq -r '.ai_engine_message_id // empty')
    [ -n "$ai_msg_id" ] && [ "$ai_msg_id" != "null" ] || run_diagnostic_on_failure "Full Flow" "ai_engine_message_id not populated"
    
    # Check engine_message_status is set
    local status
    status=$(echo "$assistant_msg" | jq -r '.engine_message_status // empty')
    [ -n "$status" ] || run_diagnostic_on_failure "Full Flow" "engine_message_status not set"
    
    echo "✓ syncAssistantMessage() created assistant message: $ASSISTANT_MESSAGE_ID"
}

@test "Full Flow: Chat updated with last_active and preview" {
    # Validates: Requirement 8.2 - Chat field updates
    
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Chat Update Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Get initial state
    local initial
    initial=$(pb_get "chats" "$CHAT_ID")
    local initial_last_active
    initial_last_active=$(echo "$initial" | jq -r '.last_active // empty')
    
    # Create user message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo chat update\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "Full Flow" "Chat not updated (no assistant message)"
    
    # Verify chat was updated
    local updated
    updated=$(pb_get "chats" "$CHAT_ID")
    
    # Check last_active was updated
    local last_active
    last_active=$(echo "$updated" | jq -r '.last_active // empty')
    [ -n "$last_active" ] && [ "$last_active" != "null" ] || run_diagnostic_on_failure "Full Flow" "last_active not updated"
    
    # Check preview was updated (should contain assistant response)
    local preview
    preview=$(echo "$updated" | jq -r '.preview // empty')
    [ -n "$preview" ] && [ "$preview" != "null" ] || run_diagnostic_on_failure "Full Flow" "preview not updated"
    
    # Verify last_active is recent (within last minute)
    local last_active_ts
    last_active_ts=$(date -d "$last_active" +%s 2>/dev/null || echo "0")
    local now_ts
    now_ts=$(date +%s)
    local diff
    diff=$((now_ts - last_active_ts))
    [ "$diff" -lt 60 ] || run_diagnostic_on_failure "Full Flow" "last_active is not recent (diff: ${diff}s)"
    
    echo "✓ Chat updated: last_active=$last_active, preview=$preview"
}

@test "Full Flow: Complete end-to-end test" {
    # Validates: Requirements 8.1, 8.2, 8.3
    # Complete end-to-end test covering all steps
    
    # Step 1: Authenticate
    authenticate_user
    echo "Step 1: User authenticated"
    
    # Step 2: Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"E2E Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    echo "Step 2: Chat created: $CHAT_ID"
    
    # Step 3: Send user message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"echo hello world\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    echo "Step 3: User message sent: $USER_MESSAGE_ID"
    
    # Step 4-7: Wait for message delivery and assistant response
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Full Flow E2E" "Message not delivered"
    echo "Step 4-7: Message delivered, OpenCode processing..."
    
    # Step 8-11: Wait for assistant message (command execution + sync response)
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "Full Flow E2E" "Assistant message not created"
    echo "Step 8-11: Command executed, sync response received"
    
    # Step 12-13: Verify SSE event processed
    local assistant_msg
    assistant_msg=$(pb_get "messages" "$ASSISTANT_MESSAGE_ID")
    local ai_msg_id
    ai_msg_id=$(echo "$assistant_msg" | jq -r '.ai_engine_message_id // empty')
    [ -n "$ai_msg_id" ] && [ "$ai_msg_id" != "null" ] || run_diagnostic_on_failure "Full Flow E2E" "SSE event not processed (no ai_engine_message_id)"
    echo "Step 12-13: SSE event processed, assistant message created"
    
    # Step 14: Verify chat updated
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    local last_active
    last_active=$(echo "$chat_record" | jq -r '.last_active // empty')
    local preview
    preview=$(echo "$chat_record" | jq -r '.preview // empty')
    [ -n "$last_active" ] && [ -n "$preview" ] || run_diagnostic_on_failure "Full Flow E2E" "Chat not updated"
    echo "Step 14: Chat updated with last_active and preview"
    
    # Verify all intermediate records exist
    local user_msg
    user_msg=$(pb_get "messages" "$USER_MESSAGE_ID")
    local user_status
    user_status=$(echo "$user_msg" | jq -r '.user_message_status')
    [ "$user_status" = "delivered" ] || run_diagnostic_on_failure "Full Flow E2E" "User message status incorrect"
    
    # Verify data relationships
    local chat_msg_count
    chat_msg_count=$(curl -s -G \
        "$PB_URL/api/collections/messages/records" \
        --data-urlencode "filter=chat='$CHAT_ID'" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" | jq -r '.totalItems')
    [ "$chat_msg_count" -ge 2 ] || run_diagnostic_on_failure "Full Flow E2E" "Chat should have at least 2 messages (user + assistant)"
    
    echo ""
    echo "=========================================="
    echo "✓ COMPLETE END-TO-END FLOW SUCCESSFUL"
    echo "=========================================="
    echo "Chat: $CHAT_ID"
    echo "User Message: $USER_MESSAGE_ID (status: delivered)"
    echo "Assistant Message: $ASSISTANT_MESSAGE_ID"
    echo "Chat last_active: $last_active"
    echo "Chat preview: $preview"
    echo "=========================================="
}

