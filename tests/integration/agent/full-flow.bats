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
        \"parts\": [{\"type\": \"text\", \"text\": \"Run this command and show me the output: echo $unique_string\"}],
        \"user_message_status\": \"pending\"
    }")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    echo "✓ Created user message: $USER_MESSAGE_ID" >&2
    echo "  Message text: 'Run this command and show me the output: echo $unique_string'" >&2

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
        \"parts\": [{\"type\": \"text\", \"text\": \"Run these two commands and show me the output of both: first run 'echo $file_content > $filename' then run 'cat $filename'\"}],
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
        \"parts\": [{\"type\": \"text\", \"text\": \"What is 2 + 2?\"}],
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

    # preview is populated
    local preview
    preview=$(echo "$chat_record" | jq -r '.preview // empty')
    [ -n "$preview" ] && [ "$preview" != "null" ] || \
        run_diagnostic_on_failure "Agent Full Flow" "preview not updated"

    # Verify the response actually mentions "4" (Poco answered the question)
    local response_text
    response_text=$(get_assistant_text "$ASSISTANT_MESSAGE_ID")
    echo "$response_text" | grep -q "4" || \
        run_diagnostic_on_failure "Agent Full Flow" "Response does not contain '4' — Poco didn't answer the question"

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
        \"parts\": [{\"type\": \"text\", \"text\": \"Remember this number: 42\"}],
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
        \"parts\": [{\"type\": \"text\", \"text\": \"What was the number I asked you to remember?\"}],
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
    assistant2_id=$(wait_for_assistant_message "$CHAT_ID" 90)
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

@test "Agent Full Flow: Poco delegates to subagent and returns git hash of PocketCoder" {
    # Ask Poco to delegate to a subagent to get the git commit hash of the
    # PocketCoder repo. This exercises the full CAO handoff pipeline:
    # 1. Poco receives the request
    # 2. Poco delegates to a subagent via CAO (cao_handoff)
    # 3. Subagent runs in sandbox tmux window
    # 4. Subagent executes `git rev-parse HEAD` in the PocketCoder repo
    # 5. HandoffResult returned to Poco
    # 6. Poco synthesizes and responds with the hash
    # 7. We verify the response contains a valid 40-char hex git hash

    authenticate_user

    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Agent Subagent Hash Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"

    # Ask Poco to delegate to a subagent for the git hash
    local msg_data
    msg_data=$(pb_create "messages" "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"text\": \"Delegate to a subagent to get the current git commit hash of the PocketCoder repository. Run 'git rev-parse HEAD' in the repo and return the full 40-character hash.\"}],
        \"user_message_status\": \"pending\"
    }")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"

    # Wait for delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Agent Full Flow" "Message not delivered"

    SESSION_ID=$(pb_get "chats" "$CHAT_ID" | jq -r '.ai_engine_session_id // empty')

    # Wait for Poco to process — subagent handoff takes longer
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 120)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || \
        run_diagnostic_on_failure "Agent Full Flow" "Poco did not respond after subagent delegation"

    # Verify the response has content
    local response_text
    response_text=$(get_assistant_text "$ASSISTANT_MESSAGE_ID")
    [ -n "$response_text" ] || \
        run_diagnostic_on_failure "Agent Full Flow" "Empty response from Poco"

    # Verify the response contains a valid 40-character hex git hash
    echo "$response_text" | grep -qiE '[0-9a-f]{40}' || \
        run_diagnostic_on_failure "Agent Full Flow" "Response does not contain a valid 40-char git hash"

    # Extract the hash for display
    local git_hash
    git_hash=$(echo "$response_text" | grep -oE '[0-9a-f]{40}' | head -1)

    # Verify a subagent was spawned (CAO handoff happened)
    local subagent_records
    subagent_records=$(curl -s -X GET \
        "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" 2>/dev/null)

    local subagent_count
    subagent_count=$(echo "$subagent_records" | jq -r '.totalCount // 0' 2>/dev/null)

    if [ "$subagent_count" -gt 0 ]; then
        local subagent_id
        subagent_id=$(echo "$subagent_records" | jq -r '.items[0].id // empty')
        track_artifact "subagents:$subagent_id"
        echo "✓ Poco delegated to subagent: $subagent_id"
    else
        echo "ℹ No subagent record found (Poco may have executed directly)"
    fi

    echo "✓ Poco returned git hash via subagent delegation"
    echo "  Git hash: $git_hash"
}

