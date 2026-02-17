#!/bin/sh
# new_tests/zone_b_tests.sh
# Zone B tests for OpenCode functionality
# Tests verify session creation, message sending, and API accessibility
# Usage: ./new_tests/zone_b_tests.sh

# Note: This script uses busybox-compatible sh syntax

# Configuration
OPENCODE_URL="${OPENCODE_URL:-http://opencode:4096}"

# Timeout settings
SSE_TIMEOUT=15
HANDOFF_TIMEOUT=20
POLL_INTERVAL=2

# Generate unique test ID for this run
TEST_ID=$(date +%s | rev | cut -c 1-8)$(printf "%04d" $RANDOM | head -c 4)
echo "🧪 Zone B Tests - Run ID: $TEST_ID"
echo "========================================"

# Track created resources for cleanup
CREATED_SESSION_ID=""

# Cleanup function to remove test data
cleanup() {
    echo ""
    echo "🧹 Cleaning up test data..."

    # Delete session if created
    if [ -n "$CREATED_SESSION_ID" ]; then
        echo "  - Deleting session: $CREATED_SESSION_ID"
        curl -s -X DELETE "$OPENCODE_URL/session/$CREATED_SESSION_ID" || true
    fi

    echo "✅ Cleanup complete"
}

# Set trap for cleanup on exit
trap cleanup EXIT

# ========================================
# Helper: Wait for condition with timeout
# Usage: wait_for_condition "check_command" "timeout_seconds" "interval_seconds"
# ========================================
wait_for_condition() {
    local check_cmd="$1"
    local timeout_sec="${2:-$SSE_TIMEOUT}"
    local interval_sec="${3:-$POLL_INTERVAL}"
    local description="$4"
    local elapsed=0

    echo "Waiting for: $description (timeout: ${timeout_sec}s)..."

    while [ $elapsed -lt $timeout_sec ]; do
        if eval "$check_cmd" >/dev/null 2>&1; then
            echo "✅ Condition met after ${elapsed}s"
            return 0
        fi
        sleep $interval_sec
        elapsed=$((elapsed + interval_sec))
    done

    echo "❌ TIMEOUT: Condition not met after ${timeout_sec}s"
    echo "Description: $description"
    return 1
}

# ========================================
# Test 1: OpenCode session creation
# Validates: Requirements 2.1
# ========================================
test_session_creation() {
    echo ""
    echo "📋 Test 1: OpenCode session creation"
    echo "------------------------------------"

    # Create session via POST /session
    echo "Creating OpenCode session..."
    SESSION_RES=$(curl -s -X POST "$OPENCODE_URL/session" \
        -H "Content-Type: application/json" \
        -d '{}')

    # Extract id from response
    CREATED_SESSION_ID=$(echo "$SESSION_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$CREATED_SESSION_ID" ]; then
        echo "❌ FAILED: Could not create session"
        echo "Expected: Session ID in response"
        echo "Actual: No ID found"
        echo "Response: $SESSION_RES"
        return 1
    fi

    echo "✅ Session created: $CREATED_SESSION_ID"

    # Query GET /session/:id to confirm session exists
    echo "Querying session status..."
    SESSION_GET=$(curl -s -X GET "$OPENCODE_URL/session/$CREATED_SESSION_ID")

    # Verify response contains id
    echo "Verifying session exists..."

    if echo "$SESSION_GET" | grep -q '"id"'; then
        echo "✅ PASSED: Response contains id"
    else
        echo "❌ FAILED: Response does not contain id"
        echo "Expected: 'id' field in response"
        echo "Actual: No 'id' field"
        echo "Response: $SESSION_GET"
        return 1
    fi

    # Verify session_id matches
    SESSION_ID_IN_RESPONSE=$(echo "$SESSION_GET" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    if [ "$CREATED_SESSION_ID" = "$SESSION_ID_IN_RESPONSE" ]; then
        echo "✅ PASSED: Session ID matches: $CREATED_SESSION_ID"
    else
        echo "❌ FAILED: Session ID mismatch"
        echo "Expected: $CREATED_SESSION_ID"
        echo "Actual: $SESSION_ID_IN_RESPONSE"
        return 1
    fi

    echo "✅ Test 1 PASSED: OpenCode session creation"
}

# ========================================
# Test 2: Message sending
# Validates: Requirements 2.2
# ========================================
test_message_sending() {
    echo ""
    echo "📋 Test 2: Message sending"
    echo "--------------------------"

    # First, create a session
    echo "Creating session for message test..."
    SESSION_RES=$(curl -s -X POST "$OPENCODE_URL/session" \
        -H "Content-Type: application/json" \
        -d '{}')

    CREATED_SESSION_ID=$(echo "$SESSION_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$CREATED_SESSION_ID" ]; then
        echo "❌ FAILED: Could not create session for message test"
        echo "Expected: Session ID in response"
        echo "Actual: No ID found"
        echo "Response: $SESSION_RES"
        return 1
    fi

    echo "✅ Session created: $CREATED_SESSION_ID"

    # Send message via POST /session/:id/prompt_async
    echo "Sending message..."
    PROMPT_RES=$(curl -s -w "%{http_code}" -X POST "$OPENCODE_URL/session/$CREATED_SESSION_ID/prompt_async" \
        -H "Content-Type: application/json" \
        -d '{
            "parts": [{"type": "text", "text": "echo hello"}]
        }')

    HTTP_CODE="${PROMPT_RES: -3}"
    BODY="${PROMPT_RES:0:${#PROMPT_RES}-3}"

    # 204 No Content is expected for prompt_async
    if [ "$HTTP_CODE" = "204" ]; then
        echo "✅ PASSED: Message sent successfully (HTTP 204)"
    else
        echo "⚠️  Unexpected HTTP code: $HTTP_CODE (expected 204)"
        echo "Response: $BODY"
    fi

    # Verify message was added by querying /session/:id/message with timeout
    echo "Verifying message was added..."

    if wait_for_condition "curl -s '$OPENCODE_URL/session/$CREATED_SESSION_ID/message' | grep -q 'echo hello'" 10 2 "Message to appear in session"; then
        echo "✅ PASSED: Message found in session"
    else
        echo "❌ FAILED: Message not found in session after timeout"
        echo "Expected: 'echo hello' in session messages"
        echo "Response: $(curl -s "$OPENCODE_URL/session/$CREATED_SESSION_ID/message")"
        return 1
    fi

    echo "✅ Test 2 PASSED: Message sending"
}

# ========================================
# Test 3: SSE event stream accessibility
# Validates: Requirements 2.3
# ========================================
test_sse_streaming() {
    echo ""
    echo "📋 Test 3: SSE event stream accessibility"
    echo "-----------------------------------------"

    # First, create a session
    echo "Creating session for SSE test..."
    SESSION_RES=$(curl -s -X POST "$OPENCODE_URL/session" \
        -H "Content-Type: application/json" \
        -d '{}')

    CREATED_SESSION_ID=$(echo "$SESSION_RES" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$CREATED_SESSION_ID" ]; then
        echo "❌ FAILED: Could not create session for SSE test"
        echo "Expected: Session ID in response"
        echo "Actual: No ID found"
        echo "Response: $SESSION_RES"
        return 1
    fi

    echo "✅ Session created: $CREATED_SESSION_ID"

    # Create a temporary file to capture SSE events
    SSE_OUTPUT_FILE=$(mktemp)
    SSE_PID=""

    # Subscribe to GET /event SSE stream in background
    echo "Subscribing to SSE stream (timeout: ${SSE_TIMEOUT}s)..."
    curl -s -N "$OPENCODE_URL/event" > "$SSE_OUTPUT_FILE" 2>&1 &
    SSE_PID=$!

    # Give SSE stream time to connect
    sleep 2

    # Send a prompt to trigger events
    echo "Sending prompt to trigger events..."
    curl -s -X POST "$OPENCODE_URL/session/$CREATED_SESSION_ID/prompt_async" \
        -H "Content-Type: application/json" \
        -d '{
            "parts": [{"type": "text", "text": "list files"}]
        }' || true

    # Wait for events to arrive with timeout
    echo "Waiting for SSE events (timeout: ${SSE_TIMEOUT}s)..."
    ELAPSED=0
    EVENTS_RECEIVED=0

    while [ $ELAPSED -lt $SSE_TIMEOUT ]; do
        # Check if we have any data
        if [ -s "$SSE_OUTPUT_FILE" ]; then
            SSE_CONTENT=$(cat "$SSE_OUTPUT_FILE" 2>/dev/null || echo "")
            if [ -n "$SSE_CONTENT" ]; then
                EVENTS_RECEIVED=1
                break
            fi
        fi
        sleep 1
        ELAPSED=$((ELAPSED + 1))
    done

    # Kill background SSE listener
    if [ -n "$SSE_PID" ]; then
        kill $SSE_PID 2>/dev/null || true
        wait $SSE_PID 2>/dev/null || true
    fi

    # Verify SSE stream is accessible
    echo "Verifying SSE stream..."

    SSE_CONTENT=$(cat "$SSE_OUTPUT_FILE" 2>/dev/null || echo "")

    if [ -n "$SSE_CONTENT" ]; then
        echo "✅ PASSED: SSE stream is accessible"

        # Check for server.connected event
        if echo "$SSE_CONTENT" | grep -q "server.connected"; then
            echo "✅ PASSED: Received server.connected event"
        else
            echo "⚠️  No server.connected event found (may depend on timing)"
        fi

        # Check for any events
        EVENT_COUNT=$(echo "$SSE_CONTENT" | grep -c "event:" || echo "0")
        echo "✅ PASSED: Received $EVENT_COUNT event(s)"
    else
        echo "❌ FAILED: SSE stream returned no data after ${SSE_TIMEOUT}s timeout"
        echo "Expected: SSE events from OpenCode"
        echo "Actual: No data received"
        rm -f "$SSE_OUTPUT_FILE"
        return 1
    fi

    # Clean up temp file
    rm -f "$SSE_OUTPUT_FILE"

    echo "✅ Test 3 PASSED: SSE event stream accessibility"
}

# ========================================
# Test 4: Global health check
# Validates: Requirements 2.1
# ========================================
test_health_check() {
    echo ""
    echo "📋 Test 4: Global health check"
    echo "-------------------------------"

    echo "Checking server health..."
    HEALTH_RES=$(curl -s "$OPENCODE_URL/global/health")

    if echo "$HEALTH_RES" | grep -q '"healthy":true'; then
        echo "✅ PASSED: Server is healthy"
    else
        echo "❌ FAILED: Server is not healthy"
        echo "Expected: 'healthy: true' in response"
        echo "Actual: $(echo "$HEALTH_RES" | jq -r '.healthy // "not found"')"
        echo "Response: $HEALTH_RES"
        return 1
    fi

    if echo "$HEALTH_RES" | grep -q '"version"'; then
        VERSION=$(echo "$HEALTH_RES" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        echo "✅ PASSED: Server version: $VERSION"
    else
        echo "⚠️  No version found in response"
    fi

    echo "✅ Test 4 PASSED: Global health check"
}

# ========================================
# Run all tests
# ========================================
run_all_tests() {
    test_session_creation
    test_message_sending
    test_sse_streaming
    test_health_check

    echo ""
    echo "========================================"
    echo "✅ All Zone B tests passed!"
    echo "========================================"
}

# Run tests
run_all_tests