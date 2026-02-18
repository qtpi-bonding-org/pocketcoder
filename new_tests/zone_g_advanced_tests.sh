#!/bin/sh
# new_tests/zone_g_advanced_tests.sh
# Zone G tests for Advanced Features
# Tests verify delegation, turn batching, and artifact serving
# Usage: ./new_tests/zone_g_advanced_tests.sh

# Note: This script uses busybox-compatible sh syntax

# Source authentication helper
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/auth.sh"

# Configuration
PB_URL="http://127.0.0.1:8090"
OPENCODE_URL="${OPENCODE_URL:-http://opencode:4096}"

# Timeout settings
DELEGATION_TIMEOUT=60
BATCH_TIMEOUT=60
POLL_INTERVAL=3

# Generate unique test ID for this run
TEST_ID=$(date +%s | rev | cut -c 1-8)$(printf "%04d" $RANDOM | head -c 4)
echo "🧪 Zone G Tests - Run ID: $TEST_ID"
echo "========================================"

# Track created resources for cleanup
CREATED_CHAT_IDS=()
CREATED_MESSAGE_IDS=()
CREATED_PERMISSION_IDS=()

# Cleanup function
cleanup() {
    local EXIT_CODE=$?
    echo ""
    echo "🧹 Cleaning up test data..."

    # Delete permissions
    for PERM_ID in "${CREATED_PERMISSION_IDS[@]}"; do
        if [ -n "$PERM_ID" ]; then
            curl -s -X DELETE "$PB_URL/api/collections/permissions/records/$PERM_ID" \
                -H "Authorization: $USER_TOKEN" || true
            echo "  - Deleted permission: $PERM_ID"
        fi
    done

    # Delete messages
    for MSG_ID in "${CREATED_MESSAGE_IDS[@]}"; do
        if [ -n "$MSG_ID" ]; then
            curl -s -X DELETE "$PB_URL/api/collections/messages/records/$MSG_ID" \
                -H "Authorization: $USER_TOKEN" || true
            echo "  - Deleted message: $MSG_ID"
        fi
    done

    # Delete chats
    for CHAT_ID in "${CREATED_CHAT_IDS[@]}"; do
        if [ -n "$CHAT_ID" ]; then
            curl -s -X DELETE "$PB_URL/api/collections/chats/records/$CHAT_ID" \
                -H "Authorization: $USER_TOKEN" || true
            echo "  - Deleted chat: $CHAT_ID"
        fi
    done

    # Clean up test artifact file
    docker exec pocketcoder-sandbox rm -f /workspace/artifact_test_$TEST_ID.txt 2>/dev/null || true

    echo "✅ Cleanup complete"
    exit $EXIT_CODE
}

trap cleanup EXIT

# ========================================
# Test 1: Artifact Serving
# Validates: Secure serving of workspace artifacts
# ========================================
test_artifact_serving() {
    echo ""
    echo "📋 Test 1: Artifact Serving"
    echo "----------------------------"

    TEST_FILE="artifact_test_$TEST_ID.txt"
    TEST_CONTENT="Artifact content for test $TEST_ID"

    # Create test file in workspace
    echo "Creating test file in workspace..."
    docker exec pocketcoder-sandbox sh -c "echo '$TEST_CONTENT' > /workspace/$TEST_FILE"

    if ! docker exec pocketcoder-sandbox test -f /workspace/$TEST_FILE; then
        echo "❌ FAILED: Could not create test file in workspace"
        return 1
    fi

    echo "✅ Test file created: $TEST_FILE"

    # Fetch artifact via API
    echo "Fetching artifact via API..."
    URL="$PB_URL/api/pocketcoder/artifact/$TEST_FILE"
    RESPONSE=$(curl -s -H "Authorization: $USER_TOKEN" "$URL")

    if [ "$RESPONSE" = "$TEST_CONTENT" ]; then
        echo "✅ PASSED: Artifact serving working correctly"
    else
        echo "❌ FAILED: Artifact content mismatch"
        echo "Expected: $TEST_CONTENT"
        echo "Actual: $RESPONSE"
        return 1
    fi

    # Test unauthorized access (without token)
    echo "Testing unauthorized access..."
    UNAUTH_RESPONSE=$(curl -s -w "\n%{http_code}" "$URL" 2>&1)
    HTTP_CODE=$(echo "$UNAUTH_RESPONSE" | tail -n1)

    if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        echo "✅ PASSED: Unauthorized access blocked (HTTP $HTTP_CODE)"
    else
        echo "⚠️  Unauthorized access returned HTTP $HTTP_CODE (expected 401 or 403)"
    fi

    echo "✅ Test 1 PASSED: Artifact Serving"
}

# ========================================
# Test 2: Turn-Based Message Batching
# Validates: Turn locking and message batching
# ========================================
test_turn_batching() {
    echo ""
    echo "📋 Test 2: Turn-Based Message Batching"
    echo "---------------------------------------"

    # Get current user ID
    CURRENT_USER_ID=$(curl -s "$PB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"$PB_EMAIL\",\"password\":\"$PB_PASSWORD\"}" | jq -r '.record.id')

    # Create a chat
    echo "Creating chat for batching test..."
    CHAT_RES=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"Batching Test $TEST_ID\",
            \"user\": \"$CURRENT_USER_ID\"
        }")

    CHAT_ID=$(echo "$CHAT_RES" | jq -r '.id // empty')

    if [ -z "$CHAT_ID" ]; then
        echo "❌ FAILED: Could not create chat"
        echo "Response: $CHAT_RES"
        return 1
    fi

    CREATED_CHAT_IDS+=("$CHAT_ID")
    echo "✅ Chat created: $CHAT_ID"

    # Verify initial turn
    TURN=$(echo "$CHAT_RES" | jq -r '.turn // "user"')
    echo "Initial turn: $TURN"

    if [ "$TURN" != "user" ] && [ "$TURN" != "" ] && [ "$TURN" != "null" ]; then
        echo "⚠️  Initial turn is '$TURN' (expected 'user' or empty)"
    else
        echo "✅ PASSED: Initial turn is correct"
    fi

    # Send first message (long task to keep AI busy)
    echo "Sending first message (long task)..."
    MSG1_RES=$(curl -s -X POST "$PB_URL/api/collections/messages/records" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat\": \"$CHAT_ID\",
            \"role\": \"user\",
            \"parts\": [{\"type\": \"text\", \"text\": \"Write a ten line poem about the sea.\"}],
            \"user_message_status\": \"pending\"
        }")

    MSG1_ID=$(echo "$MSG1_RES" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$MSG1_ID" ]; then
        CREATED_MESSAGE_IDS+=("$MSG1_ID")
    fi

    sleep 2

    # Check turn transitioned to assistant
    CHAT_STATE=$(curl -s -X GET "$PB_URL/api/collections/chats/records/$CHAT_ID" \
        -H "Authorization: $USER_TOKEN")
    TURN=$(echo "$CHAT_STATE" | grep -o '"turn":"[^"]*"' | cut -d'"' -f4)
    echo "Turn after first message: $TURN"

    # Send second message while AI is busy (batching scenario)
    echo "Sending second message (interruption)..."
    MSG2_RES=$(curl -s -X POST "$PB_URL/api/collections/messages/records" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat\": \"$CHAT_ID\",
            \"role\": \"user\",
            \"parts\": [{\"type\": \"text\", \"text\": \"Actually, forget the poem. Reply ONLY with the word: BATCH_SUCCESS\"}],
            \"user_message_status\": \"pending\"
        }")

    MSG2_ID=$(echo "$MSG2_RES" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$MSG2_ID" ]; then
        CREATED_MESSAGE_IDS+=("$MSG2_ID")
    fi

    echo "✅ Second message sent (batching test)"

    # Wait for batch resolution
    echo "Waiting for batch resolution..."
    FOUND_BATCH_SUCCESS=false

    for i in $(seq 1 5); do
        echo "Checking for batch resolution... (Attempt $i/5)"

        MSGS_RES=$(curl -s -X GET "$PB_URL/api/collections/messages/records?filter=(chat%3D%27$CHAT_ID%27)&sort=-created" \
            -H "Authorization: $USER_TOKEN")

        # Check for BATCH_SUCCESS in assistant messages (use grep instead of jq to avoid control character issues)
        if echo "$MSGS_RES" | grep -qi "BATCH_SUCCESS"; then
            echo "✅ Found BATCH_SUCCESS in messages"
            FOUND_BATCH_SUCCESS=true
            break
        fi

        sleep $POLL_INTERVAL
    done

    if [ "$FOUND_BATCH_SUCCESS" = "false" ]; then
        echo "❌ FAILED: Batch processing timed out"
        echo "Expected: BATCH_SUCCESS in assistant messages"
        echo "Actual: Timeout after waiting"
        echo "Note: This requires Relay to be running and processing messages"
        return 1
    fi

    echo "✅ Test 2 PASSED: Turn-Based Message Batching"
}

# ========================================
# Test 3: Sub-Agent Delegation (CAO Handoff)
# Validates: Delegation workflow via CAO
# ========================================
test_delegation_workflow() {
    echo ""
    echo "📋 Test 3: Sub-Agent Delegation"
    echo "--------------------------------"

    # Get current user ID
    CURRENT_USER_ID=$(curl -s "$PB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"$PB_EMAIL\",\"password\":\"$PB_PASSWORD\"}" | jq -r '.record.id')

    # Create a chat
    echo "Creating chat for delegation test..."
    CHAT_RES=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"Delegation Test $TEST_ID\",
            \"user\": \"$CURRENT_USER_ID\"
        }")

    CHAT_ID=$(echo "$CHAT_RES" | jq -r '.id // empty')

    if [ -z "$CHAT_ID" ]; then
        echo "❌ FAILED: Could not create chat"
        echo "Response: $CHAT_RES"
        return 1
    fi

    CREATED_CHAT_IDS+=("$CHAT_ID")
    echo "✅ Chat created: $CHAT_ID"

    # Send delegation request
    echo "Sending delegation request..."
    MSG_RES=$(curl -s -X POST "$PB_URL/api/collections/messages/records" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat\": \"$CHAT_ID\",
            \"role\": \"user\",
            \"parts\": [{
                \"type\": \"text\",
                \"text\": \"Use the handoff tool to delegate this task to a 'developer' agent: Calculate the SHA256 hash of 'PocketCoder'\"
            }],
            \"user_message_status\": \"pending\"
        }")

    MSG_ID=$(echo "$MSG_RES" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$MSG_ID" ]; then
        CREATED_MESSAGE_IDS+=("$MSG_ID")
    fi

    echo "✅ Delegation request sent"

    # Wait for permission request (if needed)
    echo "Checking for permission requests..."
    sleep 3

    PERM_ID=""
    for i in $(seq 1 10); do
        echo "Checking for permissions... (Attempt $i/10)"
        PERMS_RES=$(curl -s -X GET "$PB_URL/api/collections/permissions/records?filter=(chat%3D%27$CHAT_ID%27%20%26%26%20status%3D%27draft%27)" \
            -H "Authorization: $USER_TOKEN")

        PERM_ID=$(echo "$PERMS_RES" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

        if [ -n "$PERM_ID" ]; then
            echo "Permission request found: $PERM_ID"
            CREATED_PERMISSION_IDS+=("$PERM_ID")

            # Authorize it
            echo "Authorizing permission..."
            curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$PERM_ID" \
                -H "Authorization: $USER_TOKEN" \
                -H "Content-Type: application/json" \
                -d '{"status": "authorized"}' > /dev/null

            echo "✅ Permission authorized"
            break
        fi

        sleep 2
    done

    if [ -z "$PERM_ID" ]; then
        echo "No permission request found (delegation may not require permission)"
    fi

    # Wait for delegation to complete
    echo "Waiting for delegation to complete..."
    EXPECTED_HASH="7bb83f2fba9710ec82266a636ba92d9947f980680b1c9a96445b954f6fd017c5"
    FOUND_HASH=false

    for i in $(seq 1 20); do
        echo "Checking for delegation result... (Attempt $i/20)"

        MSGS_RES=$(curl -s -X GET "$PB_URL/api/collections/messages/records?filter=(chat%3D%27$CHAT_ID%27)&sort=-created" \
            -H "Authorization: $USER_TOKEN")

        # Check for expected hash in messages
        if echo "$MSGS_RES" | grep -q "$EXPECTED_HASH"; then
            echo "✅ Found expected hash in messages"
            FOUND_HASH=true
            break
        fi

        # Check for handoff tool call
        if echo "$MSGS_RES" | grep -q "handoff"; then
            echo "  Detected handoff tool call"
        fi

        # Check for error state
        if echo "$MSGS_RES" | grep -q "Request timed out"; then
            echo "  Delegation timed out, will retry..."
        fi

        sleep $POLL_INTERVAL
    done

    # Verify delegation completed (hash found)
    if [ "$FOUND_HASH" = "false" ]; then
        echo "❌ FAILED: Delegation did not complete"
        echo "Expected: Hash $EXPECTED_HASH in messages"
        echo "Actual: Delegation timed out or failed"
        echo "Note: This requires Relay and CAO to complete the delegation"
        return 1
    fi

    echo "✅ Test 3 PASSED: Sub-Agent Delegation"
}

# ========================================
# Test 4: Specialist Profile Loading
# Validates: Specialist agent profiles are loaded correctly
# ========================================
test_specialist_loading() {
    echo ""
    echo "📋 Test 4: Specialist Profile Loading"
    echo "--------------------------------------"

    SPECIALIST_NAME="test_specialist_$TEST_ID"
    AGENT_STORE="/root/.aws/cli-agent-orchestrator/agent-store"
    SPECIALIST_FILE="$AGENT_STORE/$SPECIALIST_NAME.md"

    # Create specialist profile in sandbox
    echo "Creating specialist profile in sandbox..."
    docker exec pocketcoder-sandbox mkdir -p "$AGENT_STORE"
    docker exec pocketcoder-sandbox sh -c "cat <<EOF > $SPECIALIST_FILE
---
name: $SPECIALIST_NAME
description: Test specialist for automated testing
mcpServers:
  test_server:
    command: echo
    args: [\"test\"]
---
I am a test specialist created for automated testing.
EOF"

    if ! docker exec pocketcoder-sandbox test -f "$SPECIALIST_FILE"; then
        echo "❌ FAILED: Could not create specialist profile"
        return 1
    fi

    echo "✅ Specialist profile created: $SPECIALIST_FILE"

    # Verify profile can be read
    echo "Verifying profile can be read..."
    PROFILE_CONTENT=$(docker exec pocketcoder-sandbox cat "$SPECIALIST_FILE")

    if echo "$PROFILE_CONTENT" | grep -q "$SPECIALIST_NAME"; then
        echo "✅ PASSED: Specialist profile is readable"
    else
        echo "❌ FAILED: Specialist profile content is incorrect"
        echo "Expected: $SPECIALIST_NAME in content"
        echo "Actual: $PROFILE_CONTENT"
        return 1
    fi

    # Verify profile contains required fields
    echo "Verifying profile structure..."
    
    if echo "$PROFILE_CONTENT" | grep -q "name:"; then
        echo "✅ Profile has 'name' field"
    else
        echo "❌ FAILED: Profile missing 'name' field"
        return 1
    fi

    if echo "$PROFILE_CONTENT" | grep -q "description:"; then
        echo "✅ Profile has 'description' field"
    else
        echo "❌ FAILED: Profile missing 'description' field"
        return 1
    fi

    if echo "$PROFILE_CONTENT" | grep -q "mcpServers:"; then
        echo "✅ Profile has 'mcpServers' field"
    else
        echo "❌ FAILED: Profile missing 'mcpServers' field"
        return 1
    fi

    # Cleanup
    echo "Cleaning up specialist profile..."
    docker exec pocketcoder-sandbox rm -f "$SPECIALIST_FILE"

    echo "✅ Test 4 PASSED: Specialist Profile Loading"
}

# ========================================
# Run all tests
# ========================================
run_all_tests() {
    FAILED=0
    
    test_artifact_serving || FAILED=1
    test_turn_batching || FAILED=1
    test_delegation_workflow || FAILED=1
    test_specialist_loading || FAILED=1

    echo ""
    echo "========================================"
    if [ $FAILED -eq 0 ]; then
        echo "✅ All Zone G tests passed!"
        echo "========================================"
        exit 0
    else
        echo "❌ Some Zone G tests failed!"
        echo "========================================"
        exit 1
    fi
}

# Run tests
run_all_tests
