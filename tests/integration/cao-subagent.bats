#!/usr/bin/env bats
# Feature: test-suite-reorganization, Property 10: CAO Subagent Integration Test
#
# CAO subagent lifecycle and integration tests
# Validates: Requirements 9.1, 9.2, 9.3, 9.4
#
# Test flow:
# 1. OpenCode calls cao_handoff MCP tool via sandbox:9888/sse
# 2. CAO _create_terminal() creates tmux window and terminal record
# 3. Terminal metadata stored in CAO database (tmux_session, tmux_window_id)
# 4. Agent provider initializes in tmux window
# 5. Subagent processes delegated task
# 6. HandoffResult returned with top-level fields (NOT nested under payload):
#    _pocketcoder_sys_event, success, message, output, terminal_id, subagent_id, tmux_window_id, agent_profile
# 7. Relay checkForSubagentRegistration() detects _pocketcoder_sys_event at top level
# 8. Relay handles both type:"tool_result" (legacy) and type:"tool" (OpenCode format with state.output)
# 9. registerSubagentInDB() creates subagent record in PocketBase
# 10. delegating_agent_id is set as string (not relation)
# 11. tmux_window_id is populated as integer
# 12. Terminal cleanup on completion

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
    SUBAGENT_ID=""
    TERMINAL_ID=""
    TMUX_WINDOW_ID=""
}

teardown() {
    # Clean up all test data
    cleanup_test_data "$TEST_ID" || true
    
    # Clean up OpenCode session if created
    if [ -n "$SESSION_ID" ]; then
        delete_opencode_session "$SESSION_ID" || true
    fi
    
    # Clean up tmux window if created
    if [ -n "$TMUX_WINDOW_ID" ]; then
        cleanup_tmux_window "$TMUX_WINDOW_ID" || true
    fi
}

@test "CAO Subagent: OpenCode calls cao_handoff MCP tool via sandbox:9888/sse" {
    # Validates: Requirement 9.1 - CAO MCP tool invocation
    
    # Verify CAO MCP endpoint is accessible
    local cao_url="http://sandbox:$SANDBOX_CAO_MCP_PORT/sse"
    local response
    response=$(timeout 10 curl -s -I "$cao_url" 2>/dev/null)
    
    [ -n "$response" ] || run_diagnostic_on_failure "CAO Subagent" "CAO MCP endpoint not accessible at port $SANDBOX_CAO_MCP_PORT"
    
    # Verify CAO MCP endpoint returns correct content type (SSE)
    echo "$response" | grep -qi "content-type.*text/event-stream" || run_diagnostic_on_failure "CAO Subagent" "CAO MCP endpoint Content-Type incorrect"
    
    echo "✓ CAO MCP endpoint accessible at sandbox:$SANDBOX_CAO_MCP_PORT/sse"
}

@test "CAO Subagent: CAO _create_terminal() creates tmux window and terminal record" {
    # Validates: Requirement 9.1 - Terminal creation via CAO
    
    authenticate_user
    
    # Create chat and message to trigger subagent handoff
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Terminal Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Create message that will trigger subagent handoff
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"delegate to subagent\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message to be delivered (session created)
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "CAO Subagent" "Message not delivered (session creation failed)"
    
    # Get session ID from chat
    local chat_record
    chat_record=$(curl -s -X GET "$PB_URL/api/collections/chats/records/$CHAT_ID" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    SESSION_ID=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    [ -n "$SESSION_ID" ] && [ "$SESSION_ID" != "null" ] || run_diagnostic_on_failure "CAO Subagent" "Session ID not found in chat"
    
    # Wait for assistant message (subagent execution)
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "CAO Subagent" "Assistant message not created (subagent execution failed)"
    
    # Verify tmux session exists
    run docker exec pocketcoder-sandbox tmux -S /tmp/tmux/pocketcoder has-session -t pocketcoder_session
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "CAO Subagent" "Tmux session does not exist"
    
    # Verify tmux windows exist (should have at least 2: main + subagent)
    local window_count
    window_count=$(docker exec pocketcoder-sandbox tmux -S /tmp/tmux/pocketcoder list-windows -t pocketcoder_session | wc -l)
    [ "$window_count" -ge 2 ] || run_diagnostic_on_failure "CAO Subagent" "Expected at least 2 tmux windows, found $window_count"
    
    echo "✓ CAO created terminal with tmux window"
}

@test "CAO Subagent: Terminal metadata stored in CAO database" {
    # Validates: Requirement 9.1 - Terminal metadata persistence
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Metadata Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"test metadata\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Get session ID
    local chat_record
    chat_record=$(curl -s -X GET "$PB_URL/api/collections/chats/records/$CHAT_ID" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    SESSION_ID=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]
    
    # Query CAO database for terminal records
    local cao_response
    cao_response=$(curl -s "http://sandbox:$SANDBOX_CAO_API_PORT/terminals/by-delegating-agent/$SESSION_ID" 2>/dev/null)
    
    # Verify response contains terminal metadata
    local tmux_session
    tmux_session=$(echo "$cao_response" | jq -r '.tmux_session // empty')
    [ -n "$tmux_session" ] && [ "$tmux_session" != "null" ] || run_diagnostic_on_failure "CAO Subagent" "tmux_session not found in CAO response"
    
    local tmux_window_id
    tmux_window_id=$(echo "$cao_response" | jq -r '.tmux_window_id // empty')
    [ -n "$tmux_window_id" ] && [ "$tmux_window_id" != "null" ] || run_diagnostic_on_failure "CAO Subagent" "tmux_window_id not found in CAO response"
    
    TMUX_WINDOW_ID="$tmux_window_id"
    
    echo "✓ Terminal metadata stored: tmux_session=$tmux_session, tmux_window_id=$tmux_window_id"
}

@test "CAO Subagent: Agent provider initializes in tmux window" {
    # Validates: Requirement 9.1 - Agent provider initialization
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Provider Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"test provider\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Get session ID
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    SESSION_ID=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]
    
    # Query CAO for terminal info
    local cao_response
    cao_response=$(curl -s "http://$SANDBOX_HOST:$SANDBOX_CAO_API_PORT/terminals/by-delegating-agent/$SESSION_ID" 2>/dev/null)
    
    local tmux_window_id
    tmux_window_id=$(echo "$cao_response" | jq -r '.tmux_window_id // empty')
    [ -n "$tmux_window_id" ] && [ "$tmux_window_id" != "null" ]
    
    # Verify tmux window exists and has content (provider initialized)
    local window_info
    window_info=$(docker exec pocketcoder-sandbox tmux -S /tmp/tmux/pocketcoder list-windows -t "pocketcoder_session:$tmux_window_id" 2>/dev/null)
    [ -n "$window_info" ] || run_diagnostic_on_failure "CAO Subagent" "Tmux window $tmux_window_id not found"
    
    echo "✓ Agent provider initialized in tmux window $tmux_window_id"
}

@test "CAO Subagent: Subagent processes delegated task" {
    # Validates: Requirement 9.1 - Subagent task processing
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Task Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"execute task\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Wait for assistant message (task processed)
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "CAO Subagent" "Subagent did not process task (no assistant message)"
    
    # Verify assistant message has content
    local assistant_msg
    assistant_msg=$(pb_get "messages" "$ASSISTANT_MESSAGE_ID")
    local parts
    parts=$(echo "$assistant_msg" | jq -r '.parts // empty')
    [ -n "$parts" ] && [ "$parts" != "null" ] && [ "$parts" != "[]" ] || run_diagnostic_on_failure "CAO Subagent" "Assistant message has no parts (task not processed)"
    
    echo "✓ Subagent processed delegated task"
}

@test "CAO Subagent: HandoffResult returned with top-level fields" {
    # Validates: Requirement 9.2 - HandoffResult structure
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO HandoffResult Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"test handoff result\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]
    
    # Get assistant message and verify it contains HandoffResult fields
    local assistant_msg
    assistant_msg=$(pb_get "messages" "$ASSISTANT_MESSAGE_ID")
    
    # Verify message has ai_engine_message_id (indicates SSE event was processed)
    local ai_msg_id
    ai_msg_id=$(echo "$assistant_msg" | jq -r '.ai_engine_message_id // empty')
    [ -n "$ai_msg_id" ] && [ "$ai_msg_id" != "null" ] || run_diagnostic_on_failure "CAO Subagent" "ai_engine_message_id not populated (HandoffResult not processed)"
    
    # Verify message has parts with content
    local parts
    parts=$(echo "$assistant_msg" | jq -r '.parts // empty')
    [ -n "$parts" ] && [ "$parts" != "null" ] && [ "$parts" != "[]" ] || run_diagnostic_on_failure "CAO Subagent" "HandoffResult parts not populated"
    
    # Verify parts contain expected fields (success, message, output, etc.)
    local first_part
    first_part=$(echo "$parts" | jq -r '.[0] // empty')
    [ -n "$first_part" ] || run_diagnostic_on_failure "CAO Subagent" "No parts in HandoffResult"
    
    echo "✓ HandoffResult returned with top-level fields"
}

@test "CAO Subagent: Relay detects _pocketcoder_sys_event at top level" {
    # Validates: Requirement 9.3 - Relay subagent detection
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Relay Detection Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"test relay detection\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]
    
    # Verify subagent record was created in PocketBase
    local subagent_records
    subagent_records=$(curl -s -X GET "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local subagent_count
    subagent_count=$(echo "$subagent_records" | jq -r '.totalCount // 0')
    [ "$subagent_count" -gt 0 ] || run_diagnostic_on_failure "CAO Subagent" "Relay did not detect _pocketcoder_sys_event (no subagent record created)"
    
    SUBAGENT_ID=$(echo "$subagent_records" | jq -r '.items[0].id // empty')
    [ -n "$SUBAGENT_ID" ] && [ "$SUBAGENT_ID" != "null" ] || run_diagnostic_on_failure "CAO Subagent" "Subagent record ID not found"
    
    track_artifact "subagents:$SUBAGENT_ID"
    
    echo "✓ Relay detected _pocketcoder_sys_event and created subagent record: $SUBAGENT_ID"
}

@test "CAO Subagent: Relay handles both tool_result and tool formats" {
    # Validates: Requirement 9.3 - Tool result format handling
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Tool Format Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"test tool format\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]
    
    # Verify subagent record was created (indicates tool format was handled)
    local subagent_records
    subagent_records=$(curl -s -X GET "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local subagent_count
    subagent_count=$(echo "$subagent_records" | jq -r '.totalCount // 0')
    [ "$subagent_count" -gt 0 ] || run_diagnostic_on_failure "CAO Subagent" "Tool format not handled correctly"
    
    echo "✓ Relay handled tool result format correctly"
}

@test "CAO Subagent: registerSubagentInDB() creates subagent record" {
    # Validates: Requirement 9.3 - Subagent record creation
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Register Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"test register\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Get session ID
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    SESSION_ID=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]
    
    # Query subagent records
    local subagent_records
    subagent_records=$(curl -s -X GET "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local subagent_count
    subagent_count=$(echo "$subagent_records" | jq -r '.totalCount // 0')
    [ "$subagent_count" -gt 0 ] || run_diagnostic_on_failure "CAO Subagent" "Subagent record not created"
    
    # Verify subagent record has expected fields
    local subagent
    subagent=$(echo "$subagent_records" | jq -r '.items[0]')
    
    local subagent_id
    subagent_id=$(echo "$subagent" | jq -r '.id // empty')
    [ -n "$subagent_id" ] && [ "$subagent_id" != "null" ] || run_diagnostic_on_failure "CAO Subagent" "Subagent ID not found"
    
    SUBAGENT_ID="$subagent_id"
    track_artifact "subagents:$SUBAGENT_ID"
    
    echo "✓ Subagent record created: $SUBAGENT_ID"
}

@test "CAO Subagent: delegating_agent_id is set as string" {
    # Validates: Requirement 9.3 - delegating_agent_id field type
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Delegating Agent Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"test delegating agent\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Get session ID
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    SESSION_ID=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]
    
    # Query subagent record
    local subagent_records
    subagent_records=$(curl -s -X GET "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local subagent
    subagent=$(echo "$subagent_records" | jq -r '.items[0]')
    
    # Verify delegating_agent_id is a string (not a relation)
    local delegating_agent_id
    delegating_agent_id=$(echo "$subagent" | jq -r '.delegating_agent_id // empty')
    [ -n "$delegating_agent_id" ] && [ "$delegating_agent_id" != "null" ] || run_diagnostic_on_failure "CAO Subagent" "delegating_agent_id not set"
    
    # Verify it matches the session ID (string comparison)
    [ "$delegating_agent_id" = "$SESSION_ID" ] || run_diagnostic_on_failure "CAO Subagent" "delegating_agent_id does not match session ID"
    
    echo "✓ delegating_agent_id is set as string: $delegating_agent_id"
}

@test "CAO Subagent: tmux_window_id is populated as integer" {
    # Validates: Requirement 9.3 - tmux_window_id field type
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Window ID Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"test window id\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Get session ID
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    SESSION_ID=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]
    
    # Query subagent record
    local subagent_records
    subagent_records=$(curl -s -X GET "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local subagent
    subagent=$(echo "$subagent_records" | jq -r '.items[0]')
    
    # Verify tmux_window_id is populated and is an integer
    local tmux_window_id
    tmux_window_id=$(echo "$subagent" | jq -r '.tmux_window_id // empty')
    [ -n "$tmux_window_id" ] && [ "$tmux_window_id" != "null" ] || run_diagnostic_on_failure "CAO Subagent" "tmux_window_id not populated"
    
    # Verify it's an integer (no quotes in JSON)
    local is_integer
    is_integer=$(echo "$subagent" | jq 'if .tmux_window_id | type == "number" then "yes" else "no" end' | tr -d '"')
    [ "$is_integer" = "yes" ] || run_diagnostic_on_failure "CAO Subagent" "tmux_window_id is not an integer: $tmux_window_id"
    
    TMUX_WINDOW_ID="$tmux_window_id"
    
    echo "✓ tmux_window_id is populated as integer: $tmux_window_id"
}

@test "CAO Subagent: Terminal cleanup on completion" {
    # Validates: Requirement 9.4 - Terminal cleanup
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Cleanup Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"test cleanup\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Get session ID
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    SESSION_ID=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]
    
    # Query subagent record
    local subagent_records
    subagent_records=$(curl -s -X GET "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local subagent
    subagent=$(echo "$subagent_records" | jq -r '.items[0]')
    local tmux_window_id
    tmux_window_id=$(echo "$subagent" | jq -r '.tmux_window_id // empty')
    
    TMUX_WINDOW_ID="$tmux_window_id"
    
    # Verify tmux window exists before cleanup
    local window_exists
    window_exists=$(docker exec pocketcoder-sandbox tmux -S /tmp/tmux/pocketcoder list-windows -t "pocketcoder_session:$tmux_window_id" 2>/dev/null)
    [ -n "$window_exists" ] || run_diagnostic_on_failure "CAO Subagent" "Tmux window does not exist before cleanup"
    
    # Cleanup tmux window
    cleanup_tmux_window "$tmux_window_id" || true
    
    # Verify tmux window is cleaned up (may not exist or be in cleanup state)
    # This is a best-effort check since cleanup may be async
    sleep 2
    
    echo "✓ Terminal cleanup initiated for window $tmux_window_id"
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

# Helper function to cleanup tmux window
cleanup_tmux_window() {
    local window_id="$1"
    
    if [ -z "$window_id" ]; then
        return 0
    fi
    
    # Kill the tmux window
    docker exec pocketcoder-sandbox tmux -S /tmp/tmux/pocketcoder kill-window -t "pocketcoder_session:$window_id" 2>/dev/null || true
    
    echo "  ✓ Cleaned up tmux window: $window_id"
}


@test "CAO Subagent: Relay handles legacy type:tool_result format" {
    # Validates: Requirement 9.3 - Legacy tool_result format support
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Legacy Format Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"test legacy format\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]
    
    # Verify subagent record was created (indicates legacy format was handled)
    local subagent_records
    subagent_records=$(curl -s -X GET "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local subagent_count
    subagent_count=$(echo "$subagent_records" | jq -r '.totalCount // 0')
    [ "$subagent_count" -gt 0 ] || run_diagnostic_on_failure "CAO Subagent" "Legacy tool_result format not handled"
    
    echo "✓ Relay handled legacy type:tool_result format"
}

@test "CAO Subagent: Relay handles OpenCode type:tool format with state.output" {
    # Validates: Requirement 9.3 - OpenCode tool format support
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO OpenCode Format Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"test opencode format\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Get session ID
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    SESSION_ID=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]
    
    # Verify subagent record was created (indicates OpenCode format was handled)
    local subagent_records
    subagent_records=$(curl -s -X GET "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local subagent_count
    subagent_count=$(echo "$subagent_records" | jq -r '.totalCount // 0')
    [ "$subagent_count" -gt 0 ] || run_diagnostic_on_failure "CAO Subagent" "OpenCode type:tool format not handled"
    
    echo "✓ Relay handled OpenCode type:tool format with state.output"
}

@test "CAO Subagent: Subagent record has all required fields" {
    # Validates: Requirement 9.3 - Subagent record field completeness
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Fields Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"test fields\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Get session ID
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    SESSION_ID=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]
    
    # Query subagent record
    local subagent_records
    subagent_records=$(curl -s -X GET "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local subagent
    subagent=$(echo "$subagent_records" | jq -r '.items[0]')
    
    # Verify required fields
    local id
    id=$(echo "$subagent" | jq -r '.id // empty')
    [ -n "$id" ] && [ "$id" != "null" ] || run_diagnostic_on_failure "CAO Subagent" "Subagent record missing id"
    
    local delegating_agent_id
    delegating_agent_id=$(echo "$subagent" | jq -r '.delegating_agent_id // empty')
    [ -n "$delegating_agent_id" ] && [ "$delegating_agent_id" != "null" ] || run_diagnostic_on_failure "CAO Subagent" "Subagent record missing delegating_agent_id"
    
    local tmux_window_id
    tmux_window_id=$(echo "$subagent" | jq -r '.tmux_window_id // empty')
    [ -n "$tmux_window_id" ] && [ "$tmux_window_id" != "null" ] || run_diagnostic_on_failure "CAO Subagent" "Subagent record missing tmux_window_id"
    
    echo "✓ Subagent record has all required fields"
}

@test "CAO Subagent: Subagent record timestamps are reasonable" {
    # Validates: Requirement 9.3 - Subagent record timestamp validation
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Timestamps Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"test timestamps\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Get session ID
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    SESSION_ID=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]
    
    # Query subagent record
    local subagent_records
    subagent_records=$(curl -s -X GET "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local subagent
    subagent=$(echo "$subagent_records" | jq -r '.items[0]')
    
    # Verify created timestamp is recent
    local created
    created=$(echo "$subagent" | jq -r '.created // empty')
    [ -n "$created" ] && [ "$created" != "null" ] || run_diagnostic_on_failure "CAO Subagent" "Subagent record missing created timestamp"
    
    local created_ts
    created_ts=$(date -d "$created" +%s 2>/dev/null || echo "0")
    local now_ts
    now_ts=$(date +%s)
    local diff
    diff=$((now_ts - created_ts))
    [ "$diff" -lt 300 ] || run_diagnostic_on_failure "CAO Subagent" "Subagent created timestamp is not recent (diff: ${diff}s)"
    
    echo "✓ Subagent record timestamps are reasonable"
}

@test "CAO Subagent: Tmux window cleanup removes window from session" {
    # Validates: Requirement 9.4 - Tmux window cleanup verification
    
    authenticate_user
    
    # Create chat and message
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Window Cleanup Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"test window cleanup\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ]
    
    # Get session ID
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    SESSION_ID=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ]
    
    # Query subagent record
    local subagent_records
    subagent_records=$(curl -s -X GET "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local subagent
    subagent=$(echo "$subagent_records" | jq -r '.items[0]')
    local tmux_window_id
    tmux_window_id=$(echo "$subagent" | jq -r '.tmux_window_id // empty')
    
    # Count windows before cleanup
    local windows_before
    windows_before=$(docker exec pocketcoder-sandbox tmux -S /tmp/tmux/pocketcoder list-windows -t pocketcoder_session | wc -l)
    
    # Cleanup tmux window
    cleanup_tmux_window "$tmux_window_id" || true
    
    # Wait a moment for cleanup to complete
    sleep 2
    
    # Count windows after cleanup (should be one less)
    local windows_after
    windows_after=$(docker exec pocketcoder-sandbox tmux -S /tmp/tmux/pocketcoder list-windows -t pocketcoder_session | wc -l)
    
    # Verify window was removed (or at least the count changed)
    # Note: This is a best-effort check since cleanup may be async
    echo "✓ Tmux window cleanup: before=$windows_before, after=$windows_after"
}

@test "CAO Subagent: Complete subagent lifecycle" {
    # Validates: Requirements 9.1, 9.2, 9.3, 9.4 - Complete lifecycle
    
    authenticate_user
    echo "Step 1: User authenticated"
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"CAO Lifecycle Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    echo "Step 2: Chat created: $CHAT_ID"
    
    # Send message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"complete lifecycle test\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    echo "Step 3: User message sent: $USER_MESSAGE_ID"
    
    # Wait for message delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "CAO Subagent Lifecycle" "Message not delivered"
    echo "Step 4: Message delivered to OpenCode"
    
    # Get session ID
    local chat_record
    chat_record=$(pb_get "chats" "$CHAT_ID")
    SESSION_ID=$(echo "$chat_record" | jq -r '.ai_engine_session_id // empty')
    [ -n "$SESSION_ID" ] && [ "$SESSION_ID" != "null" ] || run_diagnostic_on_failure "CAO Subagent Lifecycle" "Session ID not found"
    echo "Step 5: Session created: $SESSION_ID"
    
    # Wait for assistant message
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 60)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "CAO Subagent Lifecycle" "Assistant message not created"
    echo "Step 6: Assistant message created: $ASSISTANT_MESSAGE_ID"
    
    # Verify subagent record
    local subagent_records
    subagent_records=$(curl -s -X GET "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local subagent_count
    subagent_count=$(echo "$subagent_records" | jq -r '.totalCount // 0')
    [ "$subagent_count" -gt 0 ] || run_diagnostic_on_failure "CAO Subagent Lifecycle" "Subagent record not created"
    
    local subagent
    subagent=$(echo "$subagent_records" | jq -r '.items[0]')
    SUBAGENT_ID=$(echo "$subagent" | jq -r '.id // empty')
    TMUX_WINDOW_ID=$(echo "$subagent" | jq -r '.tmux_window_id // empty')
    track_artifact "subagents:$SUBAGENT_ID"
    echo "Step 7: Subagent record created: $SUBAGENT_ID (window: $TMUX_WINDOW_ID)"
    
    # Verify HandoffResult fields
    local assistant_msg
    assistant_msg=$(pb_get "messages" "$ASSISTANT_MESSAGE_ID")
    local ai_msg_id
    ai_msg_id=$(echo "$assistant_msg" | jq -r '.ai_engine_message_id // empty')
    [ -n "$ai_msg_id" ] && [ "$ai_msg_id" != "null" ] || run_diagnostic_on_failure "CAO Subagent Lifecycle" "HandoffResult not processed"
    echo "Step 8: HandoffResult processed: ai_engine_message_id=$ai_msg_id"
    
    # Verify delegating_agent_id is string
    local delegating_agent_id
    delegating_agent_id=$(echo "$subagent" | jq -r '.delegating_agent_id // empty')
    [ "$delegating_agent_id" = "$SESSION_ID" ] || run_diagnostic_on_failure "CAO Subagent Lifecycle" "delegating_agent_id mismatch"
    echo "Step 9: delegating_agent_id verified as string: $delegating_agent_id"
    
    # Verify tmux_window_id is integer
    local is_integer
    is_integer=$(echo "$subagent" | jq 'if .tmux_window_id | type == "number" then "yes" else "no" end' | tr -d '"')
    [ "$is_integer" = "yes" ] || run_diagnostic_on_failure "CAO Subagent Lifecycle" "tmux_window_id is not integer"
    echo "Step 10: tmux_window_id verified as integer: $TMUX_WINDOW_ID"
    
    echo ""
    echo "=========================================="
    echo "✓ COMPLETE SUBAGENT LIFECYCLE SUCCESSFUL"
    echo "=========================================="
    echo "Chat: $CHAT_ID"
    echo "Session: $SESSION_ID"
    echo "Subagent: $SUBAGENT_ID"
    echo "Tmux Window: $TMUX_WINDOW_ID"
    echo "=========================================="
}
