#!/bin/bash
# tests/helpers/wait.sh
# Wait/polling utility functions for test infrastructure
# Provides wait_for_condition, retry logic, and polling helpers
# Usage: source helpers/wait.sh

# Configuration defaults
DEFAULT_TIMEOUT="${TEST_TIMEOUT:-60}"
DEFAULT_RETRY_COUNT="${TEST_RETRY_COUNT:-3}"
DEFAULT_RETRY_DELAY="${TEST_RETRY_DELAY:-2}"
POLL_INTERVAL="${POLL_INTERVAL:-1}"

# Wait for a condition to be true with timeout
# Args: timeout_seconds condition_command [interval]
# Usage: wait_for_condition 30 "curl -s http://localhost:3000/health | grep -q ok"
# Returns: 0 on success, 1 on timeout
wait_for_condition() {
    local timeout="$1"
    local condition="$2"
    local interval="${3:-$POLL_INTERVAL}"
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    echo "Waiting for condition (timeout: ${timeout}s)..."
    
    while [ $(date +%s) -lt $end_time ]; do
        if eval "$condition" > /dev/null 2>&1; then
            local elapsed=$(($(date +%s) - start_time))
            echo "  ✓ Condition met after ${elapsed}s"
            return 0
        fi
        sleep "$interval"
    done
    
    local elapsed=$timeout
    echo "  ✗ Timeout after ${elapsed}s - condition not met"
    return 1
}

# Wait for HTTP endpoint to be available
# Args: url [timeout] [expected_content]
# Usage: wait_for_endpoint "http://localhost:3000/health" 30
# Returns: 0 on success, 1 on timeout
wait_for_endpoint() {
    local url="$1"
    local timeout="${2:-$DEFAULT_TIMEOUT}"
    local expected="$3"
    
    echo "Waiting for endpoint: $url (timeout: ${timeout}s)"
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [ $(date +%s) -lt $end_time ]; do
        local response
        response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null)
        local http_code=$(echo "$response" | tail -n1)
        local body=$(echo "$response" | sed '$d')
        
        if [ "$http_code" = "200" ]; then
            if [ -n "$expected" ]; then
                if echo "$body" | grep -q "$expected"; then
                    local elapsed=$(($(date +%s) - start_time))
                    echo "  ✓ Endpoint available after ${elapsed}s (content matched)"
                    return 0
                fi
            else
                local elapsed=$(($(date +%s) - start_time))
                echo "  ✓ Endpoint available after ${elapsed}s (HTTP 200)"
                return 0
            fi
        fi
        
        sleep "$POLL_INTERVAL"
    done
    
    echo "  ✗ Timeout waiting for endpoint: $url"
    return 1
}

# Wait for port to be available
# Args: host port [timeout]
# Usage: wait_for_port "localhost" 3000 30
# Returns: 0 on success, 1 on timeout
wait_for_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-$DEFAULT_TIMEOUT}"
    
    echo "Waiting for port $host:$port (timeout: ${timeout}s)"
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [ $(date +%s) -lt $end_time ]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            local elapsed=$(($(date +%s) - start_time))
            echo "  ✓ Port $host:$port available after ${elapsed}s"
            return 0
        fi
        sleep "$POLL_INTERVAL"
    done
    
    echo "  ✗ Timeout waiting for port $host:$port"
    return 1
}

# Retry a command with exponential backoff
# Args: retry_count delay command [args...]
# Usage: retry 3 2 "curl -s http://localhost:3000/health | grep -q ok"
# Returns: 0 on success, 1 on all retries failed
retry() {
    local retry_count="$1"
    local delay="$2"
    shift 2
    local cmd="$@"
    
    local attempt=0
    local max_attempts=$((retry_count + 1))
    
    echo "Executing command with $retry_count retries (delay: ${delay}s)"
    
    while [ $attempt -lt $max_attempts ]; do
        if eval "$cmd" > /dev/null 2>&1; then
            echo "  ✓ Command succeeded on attempt $((attempt + 1))"
            return 0
        fi
        
        attempt=$((attempt + 1))
        
        if [ $attempt -lt $max_attempts ]; then
            echo "  Attempt $attempt failed, retrying in ${delay}s..."
            sleep "$delay"
            # Exponential backoff
            delay=$((delay * 2))
        fi
    done
    
    echo "  ✗ Command failed after $max_attempts attempts"
    return 1
}

# Retry with fixed delay (as per requirement: 3 attempts, 2s delay)
# Args: command [args...]
# Usage: retry_fixed "curl -s http://localhost:3000/health"
# Returns: 0 on success, 1 on all retries failed
retry_fixed() {
    local cmd="$@"
    
    echo "Executing command with retry logic (3 attempts, 2s delay)"
    
    for attempt in 1 2 3; do
        if eval "$cmd" > /dev/null 2>&1; then
            echo "  ✓ Command succeeded on attempt $attempt"
            return 0
        fi
        
        if [ $attempt -lt 3 ]; then
            echo "  Attempt $attempt failed, retrying in 2s..."
            sleep 2
        fi
    done
    
    echo "  ✗ Command failed after 3 attempts"
    return 1
}

# Poll until condition is met or timeout
# Args: condition_command poll_interval timeout
# Usage: poll_until "curl -s http://localhost:3000/status | grep -q ready" 1 30
# Returns: 0 on success, 1 on timeout
poll_until() {
    local condition="$1"
    local interval="${2:-$POLL_INTERVAL}"
    local timeout="${3:-$DEFAULT_TIMEOUT}"
    
    wait_for_condition "$timeout" "$condition" "$interval"
}

# Wait for container to be healthy
# Args: container_name [timeout]
# Usage: wait_for_container_health "pocketcoder-opencode" 30
# Returns: 0 on healthy, 1 on timeout or unhealthy
wait_for_container_health() {
    local container="$1"
    local timeout="${2:-$DEFAULT_TIMEOUT}"
    
    echo "Waiting for container $container to be healthy (timeout: ${timeout}s)"
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [ $(date +%s) -lt $end_time ]; do
        local status
        status=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null)
        
        if [ "$status" = "healthy" ]; then
            local elapsed=$(($(date +%s) - start_time))
            echo "  ✓ Container $container healthy after ${elapsed}s"
            return 0
        fi
        
        sleep "$POLL_INTERVAL"
    done
    
    echo "  ✗ Timeout waiting for container $container to be healthy"
    return 1
}

# Wait for tmux session to exist
# Args: session_name [timeout]
# Usage: wait_for_tmux_session "pocketcoder_session" 10
# Returns: 0 on success, 1 on timeout
wait_for_tmux_session() {
    local session="$1"
    local timeout="${2:-30}"
    
    echo "Waiting for tmux session $session (timeout: ${timeout}s)"
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [ $(date +%s) -lt $end_time ]; do
        if docker exec pocketcoder-sandbox tmux has-session -t "$session" 2>/dev/null; then
            local elapsed=$(($(date +%s) - start_time))
            echo "  ✓ Tmux session $session available after ${elapsed}s"
            return 0
        fi
        sleep "$POLL_INTERVAL"
    done
    
    echo "  ✗ Timeout waiting for tmux session $session"
    return 1
}

# Wait for SSE event stream to be active
# Args: sse_url [timeout]
# Usage: wait_for_sse_stream "http://localhost:3000/event" 10
# Returns: 0 on success, 1 on timeout
wait_for_sse_stream() {
    local url="$1"
    local timeout="${2:-30}"
    
    echo "Waiting for SSE stream at $url (timeout: ${timeout}s)"
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [ $(date +%s) -lt $end_time ]; do
        # Check if we can connect and receive at least one event
        local response
        response=$(timeout 5 curl -s -N "$url" 2>/dev/null | head -5)
        
        if [ -n "$response" ]; then
            local elapsed=$(($(date +%s) - start_time))
            echo "  ✓ SSE stream active after ${elapsed}s"
            return 0
        fi
        
        sleep "$POLL_INTERVAL"
    done
    
    echo "  ✗ Timeout waiting for SSE stream"
    return 1
}

# Wait for message status transition
# Args: message_id expected_status [timeout]
# Usage: wait_for_message_status "abc123" "delivered" 60
# Returns: 0 on success, 1 on timeout
# Note: Accepts the expected status OR any status that indicates progress (e.g., "sending" or "delivered" both satisfy "sending")
wait_for_message_status() {
    local message_id="$1"
    local expected_status="$2"
    local timeout="${3:-60}"
    
    echo "Waiting for message $message_id to have status: $expected_status (timeout: ${timeout}s)"
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    # Define status progression: pending -> sending -> delivered
    local status_order=("pending" "sending" "delivered")
    local expected_index=-1
    for i in "${!status_order[@]}"; do
        if [ "${status_order[$i]}" = "$expected_status" ]; then
            expected_index=$i
            break
        fi
    done
    
    while [ $(date +%s) -lt $end_time ]; do
        local response
        response=$(curl -s -X GET "$PB_URL/api/collections/messages/records/$message_id" \
            -H "Authorization: $USER_TOKEN" \
            -H "Content-Type: application/json")
        
        local status
        status=$(echo "$response" | grep -o '"user_message_status":"[^"]*"' | cut -d'"' -f4)
        
        # Check if current status matches expected or is further along in progression
        local current_index=-1
        for i in "${!status_order[@]}"; do
            if [ "${status_order[$i]}" = "$status" ]; then
                current_index=$i
                break
            fi
        done
        
        # Accept if we've reached or passed the expected status
        if [ $current_index -ge $expected_index ] && [ $expected_index -ge 0 ]; then
            local elapsed=$(($(date +%s) - start_time))
            echo "  ✓ Message status is $status (expected: $expected_status) after ${elapsed}s"
            return 0
        fi
        
        sleep "$POLL_INTERVAL"
    done
    
    echo "  ✗ Timeout waiting for message status: $expected_status"
    return 1
}

# Get message status by ID
# Args: message_id
# Returns: status string (pending, sending, delivered) or empty if not found
# Usage: status=$(get_message_status "abc123")
get_message_status() {
    local message_id="$1"
    
    if [ -z "$message_id" ]; then
        echo ""
        return 1
    fi
    
    local response
    response=$(curl -s -X GET "$PB_URL/api/collections/messages/records/$message_id" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    
    local status
    status=$(echo "$response" | grep -o '"user_message_status":"[^"]*"' | cut -d'"' -f4)
    
    echo "$status"
}

# Check if message status indicates relay has processed it (fast-path check)
# Args: message_id
# Returns: 0 if status is sending or delivered, 1 if still pending or not found
# Usage: if message_has_relay_progress "$msg_id"; then echo "Already processed"; fi
message_has_relay_progress() {
    local message_id="$1"
    local status
    status=$(get_message_status "$message_id")
    
    if [[ "$status" =~ ^(sending|delivered)$ ]]; then
        return 0
    else
        return 1
    fi
}

# Wait for a field to be populated in a record
# Args: collection record_id field_name [max_attempts]
# Returns: 0 if field is populated, 1 if timeout
# Usage: wait_for_field_populated "messages" "abc123" "parts" 10
wait_for_field_populated() {
    local collection="$1"
    local record_id="$2"
    local field_name="$3"
    local max_attempts="${4:-10}"
    
    echo "Waiting for $collection.$record_id.$field_name to be populated (max ${max_attempts}s)"
    
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        local response
        response=$(curl -s -X GET "$PB_URL/api/collections/$collection/records/$record_id" \
            -H "Authorization: $USER_TOKEN" \
            -H "Content-Type: application/json")
        
        local value
        value=$(echo "$response" | jq -r ".$field_name // empty")
        
        if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "[]" ]; then
            local elapsed=$attempt
            echo "  ✓ $collection.$record_id.$field_name populated after ${elapsed}s"
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 1
    done
    
    echo "  ✗ Timeout waiting for $collection.$record_id.$field_name to be populated"
    return 1
}

# Wait for chat turn field to be a specific value
# Args: chat_id expected_turn [timeout]
# Returns: 0 if turn matches, 1 if timeout
# Usage: wait_for_chat_turn "abc123" "assistant" 30
wait_for_chat_turn() {
    local chat_id="$1"
    local expected_turn="$2"
    local timeout="${3:-30}"
    
    echo "Waiting for chat $chat_id turn to be '$expected_turn' (timeout: ${timeout}s)"
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [ $(date +%s) -lt $end_time ]; do
        local response
        response=$(curl -s -X GET "$PB_URL/api/collections/chats/records/$chat_id" \
            -H "Authorization: $USER_TOKEN" \
            -H "Content-Type: application/json")
        
        local turn
        turn=$(echo "$response" | jq -r '.turn // empty')
        
        if [ "$turn" = "$expected_turn" ]; then
            local elapsed=$(($(date +%s) - start_time))
            echo "  ✓ Chat turn is '$expected_turn' after ${elapsed}s"
            return 0
        fi
        
        sleep 1
    done
    
    echo "  ✗ Timeout waiting for chat turn to be '$expected_turn'"
    return 1
}

# Wait for assistant message to be created in a chat
# Args: chat_id [timeout]
# Returns: assistant message ID or empty string
# Usage: assistant_id=$(wait_for_assistant_message "abc123" 60)
wait_for_assistant_message() {
    local chat_id="$1"
    local timeout="${2:-60}"
    
    echo "Waiting for assistant message in chat $chat_id (timeout: ${timeout}s)" >&2
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [ $(date +%s) -lt $end_time ]; do
        # Query for assistant message in this chat using proper URL encoding
        local response
        response=$(curl -s -G \
            "$PB_URL/api/collections/messages/records" \
            --data-urlencode "filter=chat='$chat_id' && role='assistant'" \
            --data-urlencode "sort=created" \
            -H "Authorization: $USER_TOKEN" \
            -H "Content-Type: application/json")
        
        local assistant_id
        assistant_id=$(echo "$response" | jq -r '.items[0].id // empty' 2>/dev/null)
        
        if [ -n "$assistant_id" ] && [ "$assistant_id" != "null" ]; then
            local elapsed=$(($(date +%s) - start_time))
            echo "  ✓ Assistant message found after ${elapsed}s: $assistant_id" >&2
            echo "$assistant_id"
            return 0
        fi
        
        sleep 1
    done
    
    echo "  ✗ Timeout waiting for assistant message" >&2
    echo ""
    return 1
}

# Get chat's session ID
# Args: chat_id
# Returns: ai_engine_session_id or empty
# Usage: session_id=$(get_chat_session_id "abc123")
get_chat_session_id() {
    local chat_id="$1"
    local response
    response=$(curl -s -X GET "$PB_URL/api/collections/chats/records/$chat_id" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    echo "$response" | jq -r '.ai_engine_session_id // empty'
}

# Get chat's turn field
# Args: chat_id
# Returns: turn value or empty
# Usage: turn=$(get_chat_turn "abc123")
get_chat_turn() {
    local chat_id="$1"
    local response
    response=$(curl -s -X GET "$PB_URL/api/collections/chats/records/$chat_id" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")
    echo "$response" | jq -r '.turn // empty'
}

# Create a test conversation and wait for assistant response
# Args: title [timeout]
# Returns: chat_id and assistant_id (sets CHAT_ID and ASSISTANT_ID)
# Usage: create_test_conversation "Test Conversation" 60
create_test_conversation() {
    local title="${1:-Test Conversation}"
    local timeout="${2:-60}"
    
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"$title $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Create user message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Test message\"}], \"user_message_status\": \"pending\"}")
    local MESSAGE_ID
    MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$MESSAGE_ID"
    
    # Wait for message to be delivered
    wait_for_message_status "$MESSAGE_ID" "delivered" 30
    
    # Wait for assistant message
    ASSISTANT_ID=$(wait_for_assistant_message "$CHAT_ID" "$timeout")
    
    echo "Chat: $CHAT_ID, Assistant: $ASSISTANT_ID"
}

# Verify assistant message has expected fields
# Args: assistant_id
# Returns: 0 if all fields present, 1 otherwise
# Usage: verify_assistant_message "abc123"
verify_assistant_message() {
    local assistant_id="$1"
    
    local response
    response=$(pb_get "messages" "$assistant_id")
    
    # Check required fields
    local role
    role=$(echo "$response" | jq -r '.role')
    [ "$role" = "assistant" ] || { echo "  ✗ role is not 'assistant': $role"; return 1; }
    
    local ai_msg_id
    ai_msg_id=$(echo "$response" | jq -r '.ai_engine_message_id // empty')
    [ -n "$ai_msg_id" ] && [ "$ai_msg_id" != "null" ] || { echo "  ✗ ai_engine_message_id not populated"; return 1; }
    
    local parts
    parts=$(echo "$response" | jq -r '.parts // empty')
    [ -n "$parts" ] && [ "$parts" != "null" ] && [ "$parts" != "[]" ] || { echo "  ✗ parts not populated"; return 1; }
    
    local status
    status=$(echo "$response" | jq -r '.engine_message_status // empty')
    [ -n "$status" ] || { echo "  ✗ engine_message_status not populated"; return 1; }
    
    echo "  ✓ Assistant message verified: role=$role, ai_msg_id=$ai_msg_id, status=$status"
    return 0
}

# Export functions for use in BATS
export -f wait_for_condition wait_for_endpoint wait_for_port
export -f retry retry_fixed poll_until
export -f wait_for_container_health wait_for_tmux_session
export -f wait_for_sse_stream wait_for_message_status
export -f get_message_status message_has_relay_progress
export -f wait_for_field_populated wait_for_chat_turn wait_for_assistant_message
export -f get_chat_session_id get_chat_turn
export -f create_test_conversation verify_assistant_message