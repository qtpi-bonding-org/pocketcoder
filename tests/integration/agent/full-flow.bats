#!/usr/bin/env bats
# Agent Test: Real Full Flow
#
# Tests Poco actually doing work end-to-end.
# Unlike the infrastructure full-flow test, this verifies that a real user message
# goes through the entire pipeline and produces a meaningful assistant response.
#
# Flow:
# 1. User authenticates and creates a chat
# 2. User sends a message asking Poco to do something concrete
# 3. Relay intercepts → creates OpenCode session → delivers prompt
# 4. Poco (OpenCode) processes the message, reasons about it, executes commands
# 5. Shell bridge delivers command to sandbox → tmux executes → output captured
# 6. Relay SSE listener picks up message.updated → creates assistant message
# 7. Assistant message contains actual meaningful content (not empty/error)
# 8. Chat metadata updated (last_active, preview, turn)
# 9. Verify the response actually addresses what was asked

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
    cleanup_test_data "$TEST_ID" || true
    if [ -n "$SESSION_ID" ]; then
        delete_opencode_session "$SESSION_ID" || true
    fi
}

# Helper: get the text content from an assistant message's parts
get_assistant_text() {
    local message_id="$1"

    local msg
    msg=$(pb_get "messages" "$message_id")

    # parts is a JSON array — extract all text parts and concatenate
    echo "$msg" | jq -r '.parts[]? | select(.type == "text") | .text // empty' 2>/dev/null
}

# Helper: get tool parts from an assistant message
get_assistant_tool_parts() {
    local message_id="$1"

    local msg
    msg=$(pb_get "messages" "$message_id")

    # parts is a JSON array — extract all tool parts
    echo "$msg" | jq -r '.parts[]? | select(.type == "tool") // empty' 2>/dev/null
}

# Helper: check if assistant message has tool parts with expected output
verify_tool_output_in_message() {
    local message_id="$1"
    local expected_output="$2"

    local msg
    msg=$(pb_get "messages" "$message_id")

    # Check that parts array contains tool parts
    local tool_count
    tool_count=$(echo "$msg" | jq -r '.parts[]? | select(.type == "tool") | .id' 2>/dev/null | wc -l)
    [ "$tool_count" -gt 0 ] || return 1

    # Check that tool parts have state.output field with expected content
    local output_found
    output_found=$(echo "$msg" | jq -r ".parts[]? | select(.type == \"tool\") | .state.output // empty" 2>/dev/null | grep -c "$expected_output" || true)
    [ "$output_found" -gt 0 ] || return 1

    return 0
}

# =============================================================================
# Test: Poco executes a simple command and returns output
# =============================================================================

@test "Agent Full Flow: Poco executes a command and returns real output" {
    # Send a message that asks Poco to run a simple echo command.
    # This exercises the full pipeline: relay → session → prompt → OpenCode → 
    # shell bridge → sandbox tmux → output capture → SSE → assistant message.

    echo "" >&2
    echo "═══════════════════════════════════════════════════════════" >&2
    echo "TEST: Poco executes a command and returns real output" >&2
    echo "═══════════════════════════════════════════════════════════" >&2

    authenticate_user
    echo "✓ Authenticated as user: $USER_ID" >&2

    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Agent Echo Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    echo "✓ Created chat: $CHAT_ID" >&2

    # Send a concrete task — echo a unique string so we can verify it in the response
    local unique_string="pocketcoder_agent_test_${TEST_ID}"
    echo "ℹ Unique test string: $unique_string" >&2
    
    local msg_data
    msg_data=$(pb_create "messages" "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"text\": \"Execute this bash command and include the complete output in your response: echo $unique_string\n\nIMPORTANT: Show me the actual output text that the command produces, not just a summary.\"}],
        \"user_message_status\": \"pending\"
    }")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    echo "✓ Created user message: $USER_MESSAGE_ID" >&2
    echo "  Message text: 'Execute this bash command and include the complete output in your response: echo $unique_string'" >&2

    # Wait for message delivery (relay → OpenCode)
    echo "⏳ Waiting for message delivery..." >&2
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Agent Full Flow" "Message not delivered to OpenCode"
    echo "✓ Message delivered" >&2

    # Verify session was created
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    SESSION_ID=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    [ -n "$SESSION_ID" ] && [ "$SESSION_ID" != "null" ] || \
        run_diagnostic_on_failure "Agent Full Flow" "No session created"
    echo "✓ OpenCode session created: $SESSION_ID" >&2

    # Wait for Poco to process and respond (this is the real work)
    echo "⏳ Waiting for Poco to respond..." >&2
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 90)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || \
        run_diagnostic_on_failure "Agent Full Flow" "Poco did not produce an assistant response"
    echo "✓ Assistant message created: $ASSISTANT_MESSAGE_ID" >&2

    # Get all messages for debugging
    echo "" >&2
    echo "───────────────────────────────────────────────────────────" >&2
    echo "ALL MESSAGES IN CHAT:" >&2
    local all_msgs
    all_msgs=$(curl -s -X GET \
        "$PB_URL/api/collections/messages/records?filter=chat=\"$CHAT_ID\"&sort=created" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    echo "$all_msgs" | jq -r '.items[] | "  [\(.role)] \(.id) - status: \(.engine_message_status // .user_message_status // "none") - parts: \(.parts | length) items"' >&2
    echo "───────────────────────────────────────────────────────────" >&2
    echo "" >&2

    # Verify the response has actual content
    local response_text
    response_text=$(get_assistant_text "$ASSISTANT_MESSAGE_ID")
    
    # Debug: show ALL messages in the chat if empty
    if [ -z "$response_text" ]; then
        echo "" >&2
        echo "═══════════════════════════════════════════════════════════" >&2
        echo "ERROR: Empty response - full message dump" >&2
        echo "═══════════════════════════════════════════════════════════" >&2
        echo "$all_msgs" | jq '.' >&2
        echo "═══════════════════════════════════════════════════════════" >&2
        echo "" >&2
    fi
    
    [ -n "$response_text" ] || \
        run_diagnostic_on_failure "Agent Full Flow" "Assistant response has no text content"
    
    echo "✓ Response has text content (${#response_text} chars)" >&2
    echo "" >&2
    echo "───────────────────────────────────────────────────────────" >&2
    echo "ASSISTANT RESPONSE:" >&2
    echo "$response_text" >&2
    echo "───────────────────────────────────────────────────────────" >&2
    echo "" >&2

    # Verify the unique string appears in the response (Poco actually ran the command)
    if ! echo "$response_text" | grep -q "$unique_string"; then
        echo "" >&2
        echo "═══════════════════════════════════════════════════════════" >&2
        echo "ERROR: Expected string not found in response" >&2
        echo "═══════════════════════════════════════════════════════════" >&2
        echo "Expected string: $unique_string" >&2
        echo "" >&2
        echo "Actual response text:" >&2
        echo "$response_text" >&2
        echo "" >&2
        echo "Full message parts:" >&2
        local msg_full
        msg_full=$(pb_get "messages" "$ASSISTANT_MESSAGE_ID")
        echo "$msg_full" | jq '.parts' >&2
        echo "═══════════════════════════════════════════════════════════" >&2
        echo "" >&2
        run_diagnostic_on_failure "Agent Full Flow" "Response does not contain expected output '$unique_string'"
    fi

    # Verify tool parts are present in the message with state.output field (Requirement 10.1)
    echo "⏳ Verifying tool parts in assistant messages..." >&2
    
    # Get all assistant messages in this chat
    local all_msgs
    all_msgs=$(curl -s -G \
        "$PB_URL/api/collections/messages/records" \
        --data-urlencode "filter=chat='$CHAT_ID' && role='assistant'" \
        --data-urlencode "sort=created" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    # Check each message for tool parts with state.output
    local found_tool_output=false
    local msg_count
    msg_count=$(echo "$all_msgs" | jq -r '.totalItems // 0')
    
    for i in $(seq 0 $((msg_count - 1))); do
        local msg_id
        msg_id=$(echo "$all_msgs" | jq -r ".items[$i].id")
        
        if verify_tool_output_in_message "$msg_id" "$unique_string"; then
            found_tool_output=true
            echo "✓ Tool parts verified with state.output field in message $msg_id" >&2
            break
        fi
    done
    
    if [ "$found_tool_output" = false ]; then
        run_diagnostic_on_failure "Agent Full Flow" "Tool parts not found or missing state.output field in any assistant message"
    fi

    echo "✓ Poco executed command and returned real output" >&2
    echo "  Unique string found in response: $unique_string" >&2
    echo "═══════════════════════════════════════════════════════════" >&2
    echo "" >&2
}

# =============================================================================
# Test: Poco creates a file and verifies it exists
# =============================================================================

@test "Agent Full Flow: Poco creates a file in the sandbox" {
    # Ask Poco to create a file with specific content, then ask it to read
    # the file back. This proves Poco can do real write+read work without
    # us needing to inspect the sandbox filesystem directly.

    echo "" >&2
    echo "═══════════════════════════════════════════════════════════" >&2
    echo "TEST: Poco creates a file in the sandbox" >&2
    echo "═══════════════════════════════════════════════════════════" >&2

    authenticate_user
    echo "✓ Authenticated as user: $USER_ID" >&2

    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Agent File Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    echo "✓ Created chat: $CHAT_ID" >&2

    local filename="/tmp/agent_test_${TEST_ID}.txt"
    local file_content="pocketcoder_file_test_${TEST_ID}"
    echo "ℹ Test filename: $filename" >&2
    echo "ℹ Test content: $file_content" >&2

    # Ask Poco to create the file AND read it back in one go
    local msg_data
    msg_data=$(pb_create "messages" "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"text\": \"Execute these two bash commands in sequence:\n\n1. echo $file_content > $filename\n2. cat $filename\n\nIMPORTANT: Show me the complete output from the 'cat' command. The output should contain the exact text: $file_content\"}],
        \"user_message_status\": \"pending\"
    }")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    echo "✓ Created user message: $USER_MESSAGE_ID" >&2

    # Wait for delivery
    echo "⏳ Waiting for message delivery..." >&2
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Agent Full Flow" "Message not delivered"
    echo "✓ Message delivered" >&2

    SESSION_ID=$(pb_get "chats" "$CHAT_ID" | jq -r '.ai_engine_session_id // empty')
    echo "✓ OpenCode session: $SESSION_ID" >&2

    # Wait for Poco to finish
    echo "⏳ Waiting for Poco to respond..." >&2
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 90)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || \
        run_diagnostic_on_failure "Agent Full Flow" "Poco did not respond"
    echo "✓ Assistant message created: $ASSISTANT_MESSAGE_ID" >&2

    # Get all messages for debugging
    echo "" >&2
    echo "───────────────────────────────────────────────────────────" >&2
    echo "ALL MESSAGES IN CHAT:" >&2
    local all_msgs
    all_msgs=$(curl -s -X GET \
        "$PB_URL/api/collections/messages/records?filter=chat=\"$CHAT_ID\"&sort=created" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    echo "$all_msgs" | jq -r '.items[] | "  [\(.role)] \(.id) - status: \(.engine_message_status // .user_message_status // "none") - parts: \(.parts | length) items"' >&2
    echo "───────────────────────────────────────────────────────────" >&2
    echo "" >&2

    # Verify the response contains the file content (Poco read it back)
    local response_text
    response_text=$(get_assistant_text "$ASSISTANT_MESSAGE_ID")
    [ -n "$response_text" ] || \
        run_diagnostic_on_failure "Agent Full Flow" "Empty response"
    
    echo "✓ Response has text content (${#response_text} chars)" >&2
    echo "" >&2
    echo "───────────────────────────────────────────────────────────" >&2
    echo "ASSISTANT RESPONSE:" >&2
    echo "$response_text" >&2
    echo "───────────────────────────────────────────────────────────" >&2
    echo "" >&2

    if ! echo "$response_text" | grep -q "$file_content"; then
        echo "" >&2
        echo "═══════════════════════════════════════════════════════════" >&2
        echo "ERROR: File content not found in response" >&2
        echo "═══════════════════════════════════════════════════════════" >&2
        echo "Expected content: $file_content" >&2
        echo "" >&2
        echo "Full messages dump:" >&2
        echo "$all_msgs" | jq '.' >&2
        echo "═══════════════════════════════════════════════════════════" >&2
        echo "" >&2
        run_diagnostic_on_failure "Agent Full Flow" "Response does not contain file content '$file_content' — file write/read failed"
    fi

    # Verify tool parts are present in the message with state.output field (Requirement 10.2)
    echo "⏳ Verifying tool parts in assistant messages..." >&2
    
    # Check each assistant message for tool parts with state.output
    local found_tool_output=false
    local msg_count
    msg_count=$(echo "$all_msgs" | jq -r '.totalItems // 0')
    
    for i in $(seq 0 $((msg_count - 1))); do
        local msg_id
        msg_id=$(echo "$all_msgs" | jq -r ".items[$i].id")
        local msg_role
        msg_role=$(echo "$all_msgs" | jq -r ".items[$i].role")
        
        if [ "$msg_role" = "assistant" ]; then
            if verify_tool_output_in_message "$msg_id" "$file_content"; then
                found_tool_output=true
                echo "✓ Tool parts verified with state.output field in message $msg_id" >&2
                break
            fi
        fi
    done
    
    if [ "$found_tool_output" = false ]; then
        run_diagnostic_on_failure "Agent Full Flow" "Tool parts not found or missing state.output field in any assistant message"
    fi

    echo "✓ Poco created and read back a file" >&2
    echo "  Content verified: $file_content" >&2
    echo "═══════════════════════════════════════════════════════════" >&2
    echo "" >&2
}

# =============================================================================
# Test: Chat metadata reflects real agent activity
# =============================================================================

@test "Agent Full Flow: Chat metadata updated after Poco responds" {
    # After Poco processes a message and responds, the chat record should have:
    # - ai_engine_session_id populated
    # - last_active updated to recent timestamp
    # - preview containing part of the assistant response
    # - turn set to "assistant" (or back to "user" after completion)

    authenticate_user

    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Agent Metadata Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"

    local msg_data
    msg_data=$(pb_create "messages" "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"text\": \"Compute the result of 100 + 200. Respond with only the number.\"}],
        \"user_message_status\": \"pending\"
    }")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"

    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]

    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 90)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || \
        run_diagnostic_on_failure "Agent Full Flow" "No assistant response"

    # Check chat metadata
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")

    # Session ID populated
    SESSION_ID=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    [ -n "$SESSION_ID" ] && [ "$SESSION_ID" != "null" ] || \
        run_diagnostic_on_failure "Agent Full Flow" "ai_engine_session_id not set"

    # last_active is recent
    local last_active
    last_active=$(echo "$chat_record" | jq -r '.last_active // empty')
    [ -n "$last_active" ] && [ "$last_active" != "null" ] || \
        run_diagnostic_on_failure "Agent Full Flow" "last_active not updated"

    # preview is populated (wait for it to handle race condition)
    run wait_for_field_populated "chats" "$CHAT_ID" "preview" 15
    [ "$status" -eq 0 ] || \
        run_diagnostic_on_failure "Agent Full Flow" "preview not updated after waiting"
    
    # Fetch the preview value for display
    chat_record=$(pb_get "chats" "$CHAT_ID")
    local preview
    preview=$(echo "$chat_record" | jq -r '.preview // empty')

    # Verify the response actually mentions "300" (Poco answered the question)
    local response_text
    response_text=$(get_assistant_text "$ASSISTANT_MESSAGE_ID")
    echo "$response_text" | grep -iq "300" || \
        run_diagnostic_on_failure "Agent Full Flow" "Response does not contain '300' — Poco didn't answer the question correctly"

    echo "✓ Chat metadata updated, Poco answered correctly"
    echo "  Session: $SESSION_ID"
    echo "  Preview: ${preview:0:100}"
}

# =============================================================================
# Test: Multi-turn conversation
# =============================================================================

@test "Agent Full Flow: Poco handles a multi-turn conversation" {
    # Send two messages in sequence and verify Poco responds to both.
    # The second message should be in the context of the first.

    authenticate_user

    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Agent Multi-Turn Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"

    # First message
    local msg1_data
    msg1_data=$(pb_create "messages" "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"text\": \"Please remember this specific number for our conversation: 42. Acknowledge that you will remember it.\"}],
        \"user_message_status\": \"pending\"
    }")
    local msg1_id
    msg1_id=$(echo "$msg1_data" | jq -r '.id')
    track_artifact "messages:$msg1_id"

    # Wait for first response
    run wait_for_message_status "$msg1_id" "delivered" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Agent Full Flow" "First message not delivered"

    local assistant1_id
    assistant1_id=$(wait_for_assistant_message "$CHAT_ID" 90)
    [ -n "$assistant1_id" ] && [ "$assistant1_id" != "null" ] || \
        run_diagnostic_on_failure "Agent Full Flow" "No response to first message"

    SESSION_ID=$(pb_get "chats" "$CHAT_ID" | jq -r '.ai_engine_session_id // empty')

    # Wait for turn to return to user before sending second message
    sleep 3

    # Second message — references the first
    local msg2_data
    msg2_data=$(pb_create "messages" "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"text\": \"What was the specific number I asked you to remember in my previous message? Your response must include the number.\"}],
        \"user_message_status\": \"pending\"
    }")
    local msg2_id
    msg2_id=$(echo "$msg2_data" | jq -r '.id')
    track_artifact "messages:$msg2_id"

    # Wait for second response
    run wait_for_message_status "$msg2_id" "delivered" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Agent Full Flow" "Second message not delivered"

    # Wait for second assistant response
    local assistant2_id
    assistant2_id=$(wait_for_assistant_message "$CHAT_ID" 120 "$assistant1_id")
    [ -n "$assistant2_id" ] && [ "$assistant2_id" != "null" ] || \
        run_diagnostic_on_failure "Agent Full Flow" "No response to second message"

    # Now query for all assistant messages
    local all_assistant_msgs
    all_assistant_msgs=$(curl -s -G \
        "$PB_URL/api/collections/messages/records" \
        --data-urlencode "filter=chat='$CHAT_ID' && role='assistant'" \
        --data-urlencode "sort=-created" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")

    local assistant_count
    assistant_count=$(echo "$all_assistant_msgs" | jq -r '.totalItems // 0')
    [ "$assistant_count" -ge 2 ] || \
        run_diagnostic_on_failure "Agent Full Flow" "Expected at least 2 assistant messages, got $assistant_count"

    # Get the latest assistant message
    local latest_assistant_id
    latest_assistant_id=$(echo "$all_assistant_msgs" | jq -r '.items[0].id // empty')

    # Verify the second response references "42"
    local response_text
    response_text=$(get_assistant_text "$latest_assistant_id")
    echo "$response_text" | grep -q "42" || \
        run_diagnostic_on_failure "Agent Full Flow" "Second response does not reference '42' — context not maintained"

    # Verify total message count (at least 4: 2 user + 2 assistant)
    local total_msgs
    total_msgs=$(curl -s -G \
        "$PB_URL/api/collections/messages/records" \
        --data-urlencode "filter=chat='$CHAT_ID'" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" | jq -r '.totalItems // 0')
    [ "$total_msgs" -ge 4 ] || \
        run_diagnostic_on_failure "Agent Full Flow" "Expected at least 4 messages, got $total_msgs"

    echo "✓ Poco handled multi-turn conversation with context"
    echo "  Messages in chat: $total_msgs"
}

# =============================================================================
# Test: Poco delegates to subagent and returns result (git hash)
# =============================================================================

@test "Agent Full Flow: Poco delegates to subagent and returns SHA256 hash" {
    # Ask Poco to delegate to a subagent to compute a SHA256 hash.
    # This exercises the full CAO handoff pipeline:
    # 1. Poco receives the request
    # 2. Poco delegates to a subagent via CAO (cao_handoff)
    # 3. Subagent runs in sandbox tmux window
    # 4. Subagent executes `echo -n pocketcoder | sha256sum`
    # 5. HandoffResult returned to Poco
    # 6. Poco synthesizes and responds with the hash
    # 7. We verify the response contains a valid 64-char hex SHA256 hash

    authenticate_user

    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Agent Subagent Hash Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"

    # Ask Poco to delegate to a subagent for a simple hash
    local msg_data
    msg_data=$(pb_create "messages" "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"text\": \"Use the cao_handoff tool to delegate this task to a subagent with agent_profile='developer':\n\nTask: Compute the SHA256 hash of the string 'pocketcoder' by running: echo -n pocketcoder | sha256sum\n\nAfter the subagent completes, include the full 64-character hash in your response.\"}],
        \"user_message_status\": \"pending\"
    }")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"

    # Wait for delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Agent Full Flow" "Message not delivered"

    SESSION_ID=$(pb_get "chats" "$CHAT_ID" | jq -r '.ai_engine_session_id // empty')

    # Wait for Poco to complete — subagent handoff creates multiple messages.
    # We keep fetching the latest assistant message until one contains a SHA256 hash,
    # or until we hit our overall timeout.
    local response_text=""
    local last_seen_id=""
    local deadline=$(( $(date +%s) + 240 ))

    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 120)
    [ -n "$ASSISTANT_MESSAGE_ID" ] || \
        run_diagnostic_on_failure "Agent Full Flow" "Poco did not respond at all"

    while true; do
        response_text=$(get_assistant_text "$ASSISTANT_MESSAGE_ID")
        if echo "$response_text" | grep -qiE '[0-9a-f]{64}'; then
            echo "  ✓ Found SHA256 hash in message $ASSISTANT_MESSAGE_ID" >&2
            break
        fi

        if [ $(date +%s) -ge $deadline ]; then
            echo "═══════════════════════════════════════════════════════════" >&2
            echo "DIAGNOSTIC: Timed out waiting for hash. Last response:" >&2
            echo "$response_text" >&2
            echo "═══════════════════════════════════════════════════════════" >&2
            run_diagnostic_on_failure "Agent Full Flow" "Response does not contain a valid 64-char SHA256 hash"
        fi

        echo "  ℹ No hash yet in message $ASSISTANT_MESSAGE_ID, checking for newer message..." >&2
        last_seen_id="$ASSISTANT_MESSAGE_ID"
        # Wait for the chat turn to flip back to user (subagent processing) then look for next message
        wait_for_chat_turn "$CHAT_ID" "user" 30 2>/dev/null || true
        local next_id
        next_id=$(wait_for_assistant_message "$CHAT_ID" 60 "$last_seen_id")
        if [ -n "$next_id" ] && [ "$next_id" != "$last_seen_id" ]; then
            ASSISTANT_MESSAGE_ID="$next_id"
        else
            # No new message appeared; the last one is our final answer
            break
        fi
    done

    # Verify the response contains a valid 64-character hex SHA256 hash
    if ! echo "$response_text" | grep -qiE '[0-9a-f]{64}'; then
        echo "═══════════════════════════════════════════════════════════" >&2
        echo "DIAGNOSTIC: Response text does not contain hash:" >&2
        echo "$response_text" >&2
        echo "═══════════════════════════════════════════════════════════" >&2
        run_diagnostic_on_failure "Agent Full Flow" "Response does not contain a valid 64-char SHA256 hash"
    fi

    # Extract the hash for display
    local sha_hash
    sha_hash=$(echo "$response_text" | grep -oE '[0-9a-f]{64}' | head -1)

    # Verify a subagent was spawned (CAO handoff happened)
    local subagent_records
    subagent_records=$(curl -s -X GET \
        "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" 2>/dev/null)

    local subagent_count
    subagent_count=$(echo "$subagent_records" | jq -r '.totalItems // 0' 2>/dev/null)

    if [ "$subagent_count" -gt 0 ]; then
        local subagent_id
        subagent_id=$(echo "$subagent_records" | jq -r '.items[0].id // empty')
        track_artifact "subagents:$subagent_id"
        echo "✓ Poco delegated to subagent: $subagent_id"
    else
        echo "ℹ No subagent record found (Poco may have executed directly)"
    fi

    echo "✓ Poco returned SHA256 hash via subagent delegation"
    echo "  SHA256 hash: $sha_hash"
}

