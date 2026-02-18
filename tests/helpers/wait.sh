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

# Export functions for use in BATS
export -f wait_for_condition wait_for_endpoint wait_for_port
export -f retry retry_fixed poll_until
export -f wait_for_container_health wait_for_tmux_session
export -f wait_for_sse_stream wait_for_message_status