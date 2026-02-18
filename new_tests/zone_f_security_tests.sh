#!/bin/sh
# new_tests/zone_f_security_tests.sh
# Zone F tests for Security Features
# Tests verify SSH key authentication and permission flows
# Usage: ./new_tests/zone_f_security_tests.sh

# Note: This script uses busybox-compatible sh syntax

# Source authentication helper
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/auth.sh"

# Configuration
PB_URL="http://127.0.0.1:8090"
SSH_HOST="${SSH_HOST:-localhost}"
SSH_PORT="${SSH_PORT:-2222}"
SSH_USER="${SSH_USER:-worker}"

# Generate unique test ID for this run
TEST_ID=$(date +%s | rev | cut -c 1-8)$(printf "%04d" $RANDOM | head -c 4)
TEST_USER_EMAIL="test-ssh-$TEST_ID@example.com"
TEST_USER_PASSWORD="TestPassword123!"

echo "🧪 Zone F Tests - Run ID: $TEST_ID"
echo "========================================"

# Track created resources for cleanup
TEST_USER_ID=""
SSH_KEY_ID=""
SSH_KEY_ID2=""
CREATED_CHAT_ID=""
CREATED_MESSAGE_ID=""
CREATED_PERMISSION_ID=""

# Cleanup function
cleanup() {
    echo ""
    echo "🧹 Cleaning up test data..."

    # Delete permission if created
    if [ -n "$CREATED_PERMISSION_ID" ]; then
        curl -s -X DELETE "$PB_URL/api/collections/permissions/records/$CREATED_PERMISSION_ID" \
            -H "Authorization: $USER_TOKEN" || true
        echo "  - Deleted permission: $CREATED_PERMISSION_ID"
    fi

    # Delete message if created
    if [ -n "$CREATED_MESSAGE_ID" ]; then
        curl -s -X DELETE "$PB_URL/api/collections/messages/records/$CREATED_MESSAGE_ID" \
            -H "Authorization: $USER_TOKEN" || true
        echo "  - Deleted message: $CREATED_MESSAGE_ID"
    fi

    # Delete chat if created
    if [ -n "$CREATED_CHAT_ID" ]; then
        curl -s -X DELETE "$PB_URL/api/collections/chats/records/$CREATED_CHAT_ID" \
            -H "Authorization: $USER_TOKEN" || true
        echo "  - Deleted chat: $CREATED_CHAT_ID"
    fi

    # Delete test user (cascades to SSH keys)
    if [ -n "$TEST_USER_ID" ]; then
        curl -s -X DELETE "$PB_URL/api/collections/users/records/$TEST_USER_ID" \
            -H "Authorization: $ADMIN_TOKEN" || true
        echo "  - Deleted test user: $TEST_USER_ID"
    fi

    # Remove test SSH keys
    rm -f /tmp/test_ssh_key_$TEST_ID /tmp/test_ssh_key_$TEST_ID.pub
    rm -f /tmp/test_ssh_key2_$TEST_ID /tmp/test_ssh_key2_$TEST_ID.pub

    echo "✅ Cleanup complete"
}

trap cleanup EXIT

# ========================================
# Test 1: SSH Key Registration
# Validates: SSH key creation and storage
# ========================================
test_ssh_key_registration() {
    echo ""
    echo "📋 Test 1: SSH Key Registration"
    echo "--------------------------------"

    # Create test user
    echo "Creating test user..."
    USER_RESPONSE=$(curl -s -X POST "$PB_URL/api/collections/users/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $ADMIN_TOKEN" \
        -d "{
            \"email\":\"$TEST_USER_EMAIL\",
            \"password\":\"$TEST_USER_PASSWORD\",
            \"passwordConfirm\":\"$TEST_USER_PASSWORD\"
        }")
    
    TEST_USER_ID=$(echo "$USER_RESPONSE" | jq -r '.id // empty')
    
    if [ -z "$TEST_USER_ID" ]; then
        echo "❌ FAILED: Could not create test user"
        echo "Response: $USER_RESPONSE"
        return 1
    fi
    
    echo "✅ Test user created: $TEST_USER_ID"

    # Authenticate as test user
    echo "Authenticating as test user..."
    AUTH_RESPONSE=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{
            \"identity\":\"$TEST_USER_EMAIL\",
            \"password\":\"$TEST_USER_PASSWORD\"
        }")
    
    TEST_USER_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.token // empty')
    
    if [ -z "$TEST_USER_TOKEN" ]; then
        echo "❌ FAILED: Could not authenticate test user"
        echo "Response: $AUTH_RESPONSE"
        return 1
    fi
    
    echo "✅ Test user authenticated"

    # Generate SSH key pair
    echo "Generating SSH key pair..."
    ssh-keygen -t ed25519 -f /tmp/test_ssh_key_$TEST_ID -N "" -C "test-device" > /dev/null 2>&1
    
    if [ ! -f /tmp/test_ssh_key_$TEST_ID ] || [ ! -f /tmp/test_ssh_key_$TEST_ID.pub ]; then
        echo "❌ FAILED: Could not generate SSH key pair"
        return 1
    fi
    
    TEST_PUBLIC_KEY=$(cat /tmp/test_ssh_key_$TEST_ID.pub)
    echo "✅ SSH key pair generated"

    # Calculate fingerprint
    echo "Calculating SSH key fingerprint..."
    KEY_BASE64=$(echo "$TEST_PUBLIC_KEY" | awk '{print $2}')
    FINGERPRINT="SHA256:$(echo "$KEY_BASE64" | base64 -d | shasum -a 256 | awk '{print $1}' | xxd -r -p | base64)"
    
    if [ -z "$FINGERPRINT" ]; then
        echo "❌ FAILED: Could not calculate fingerprint"
        return 1
    fi
    
    echo "✅ Fingerprint calculated: $FINGERPRINT"

    # Register SSH key
    echo "Registering SSH key to PocketBase..."
    SSH_KEY_RESPONSE=$(curl -s -X POST "$PB_URL/api/collections/ssh_keys/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $TEST_USER_TOKEN" \
        -d "{
            \"user\":\"$TEST_USER_ID\",
            \"public_key\":\"$TEST_PUBLIC_KEY\",
            \"device_name\":\"Test Device\",
            \"fingerprint\":\"$FINGERPRINT\",
            \"is_active\":true
        }")
    
    SSH_KEY_ID=$(echo "$SSH_KEY_RESPONSE" | jq -r '.id // empty')
    
    if [ -z "$SSH_KEY_ID" ]; then
        echo "❌ FAILED: Could not register SSH key"
        echo "Response: $SSH_KEY_RESPONSE"
        return 1
    fi
    
    echo "✅ SSH key registered: $SSH_KEY_ID"

    echo "✅ Test 1 PASSED: SSH Key Registration"
}

# ========================================
# Test 2: SSH Key Sync Endpoint
# Validates: SSH keys appear in sync endpoint
# ========================================
test_ssh_key_sync() {
    echo ""
    echo "📋 Test 2: SSH Key Sync Endpoint"
    echo "---------------------------------"

    echo "Checking SSH keys sync endpoint..."
    KEYS_RESPONSE=$(curl -s "$PB_URL/api/pocketcoder/ssh_keys")
    
    # Extract just the key part (without ssh-ed25519 prefix and comment)
    KEY_PART=$(echo "$TEST_PUBLIC_KEY" | awk '{print $2}')
    
    if echo "$KEYS_RESPONSE" | grep -q "$KEY_PART"; then
        echo "✅ PASSED: SSH key appears in sync endpoint"
    else
        echo "❌ FAILED: SSH key not found in sync endpoint"
        echo "Expected key part: $KEY_PART"
        echo "Response: $KEYS_RESPONSE"
        return 1
    fi

    echo "✅ Test 2 PASSED: SSH Key Sync Endpoint"
}

# ========================================
# Test 3: SSH Key Deactivation
# Validates: Deactivated keys don't sync
# ========================================
test_ssh_key_deactivation() {
    echo ""
    echo "📋 Test 3: SSH Key Deactivation"
    echo "--------------------------------"

    echo "Deactivating SSH key..."
    
    # Re-authenticate as test user to get fresh token
    AUTH_RESPONSE=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{
            \"identity\":\"$TEST_USER_EMAIL\",
            \"password\":\"$TEST_USER_PASSWORD\"
        }")
    
    TEST_USER_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.token // empty')
    
    DEACTIVATE_RESPONSE=$(curl -s -X PATCH "$PB_URL/api/collections/ssh_keys/records/$SSH_KEY_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: $TEST_USER_TOKEN" \
        -d '{"is_active":false}')
    
    IS_ACTIVE=$(echo "$DEACTIVATE_RESPONSE" | jq -r '.is_active')
    
    if [ "$IS_ACTIVE" = "false" ]; then
        echo "✅ PASSED: SSH key deactivated"
    else
        echo "❌ FAILED: Could not deactivate SSH key"
        echo "Response: $DEACTIVATE_RESPONSE"
        return 1
    fi

    # Verify key doesn't appear in sync endpoint
    echo "Verifying deactivated key is not synced..."
    sleep 1  # Give sync time to update
    
    KEYS_RESPONSE=$(curl -s "$PB_URL/api/pocketcoder/ssh_keys")
    KEY_PART=$(echo "$TEST_PUBLIC_KEY" | awk '{print $2}')
    
    if ! echo "$KEYS_RESPONSE" | grep -q "$KEY_PART"; then
        echo "✅ PASSED: Deactivated key not in sync endpoint"
    else
        echo "❌ FAILED: Deactivated key still appears in sync endpoint"
        echo "Response: $KEYS_RESPONSE"
        return 1
    fi

    echo "✅ Test 3 PASSED: SSH Key Deactivation"
}

# ========================================
# Test 4: Multiple SSH Keys Per User
# Validates: Users can have multiple keys
# ========================================
test_multiple_ssh_keys() {
    echo ""
    echo "📋 Test 4: Multiple SSH Keys Per User"
    echo "--------------------------------------"

    # Generate second key
    echo "Generating second SSH key..."
    ssh-keygen -t ed25519 -f /tmp/test_ssh_key2_$TEST_ID -N "" -C "test-device-2" > /dev/null 2>&1
    TEST_PUBLIC_KEY2=$(cat /tmp/test_ssh_key2_$TEST_ID.pub)
    KEY_BASE64_2=$(echo "$TEST_PUBLIC_KEY2" | awk '{print $2}')
    FINGERPRINT2="SHA256:$(echo "$KEY_BASE64_2" | base64 -d | shasum -a 256 | awk '{print $1}' | xxd -r -p | base64)"
    
    echo "✅ Second SSH key generated"

    # Re-authenticate as test user
    AUTH_RESPONSE=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{
            \"identity\":\"$TEST_USER_EMAIL\",
            \"password\":\"$TEST_USER_PASSWORD\"
        }")
    
    TEST_USER_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.token // empty')

    # Register second key
    echo "Registering second SSH key..."
    SSH_KEY_RESPONSE2=$(curl -s -X POST "$PB_URL/api/collections/ssh_keys/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $TEST_USER_TOKEN" \
        -d "{
            \"user\":\"$TEST_USER_ID\",
            \"public_key\":\"$TEST_PUBLIC_KEY2\",
            \"device_name\":\"Test Device 2\",
            \"fingerprint\":\"$FINGERPRINT2\",
            \"is_active\":true
        }")
    
    SSH_KEY_ID2=$(echo "$SSH_KEY_RESPONSE2" | jq -r '.id // empty')
    
    if [ -n "$SSH_KEY_ID2" ]; then
        echo "✅ PASSED: Multiple SSH keys supported"
    else
        echo "❌ FAILED: Could not register second SSH key"
        echo "Response: $SSH_KEY_RESPONSE2"
        return 1
    fi

    echo "✅ Test 4 PASSED: Multiple SSH Keys Per User"
}

# ========================================
# Test 5: Permission Request Flow
# Validates: Permission creation and authorization
# ========================================
test_permission_flow() {
    echo ""
    echo "📋 Test 5: Permission Request Flow"
    echo "-----------------------------------"

    # Create a chat
    echo "Creating chat for permission test..."
    CURRENT_USER_ID=$(curl -s "$PB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"$PB_EMAIL\",\"password\":\"$PB_PASSWORD\"}" | jq -r '.record.id')
    
    CHAT_RES=$(curl -s -X POST "$PB_URL/api/collections/chats/records" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"Permission Test $TEST_ID\",
            \"user\": \"$CURRENT_USER_ID\"
        }")

    CREATED_CHAT_ID=$(echo "$CHAT_RES" | jq -r '.id // empty')

    if [ -z "$CREATED_CHAT_ID" ]; then
        echo "❌ FAILED: Could not create chat"
        echo "Response: $CHAT_RES"
        return 1
    fi

    echo "✅ Chat created: $CREATED_CHAT_ID"

    # Create a permission request (simulating what Relay would do)
    echo "Creating permission request..."
    
    # Re-authenticate as superuser for permission creation
    source "$SCRIPT_DIR/helpers/auth.sh" --super
    
    PERMISSION_RES=$(curl -s -X POST "$PB_URL/api/collections/permissions/records" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat\": \"$CREATED_CHAT_ID\",
            \"ai_engine_permission_id\": \"perm_test_$TEST_ID\",
            \"session_id\": \"session_test_$TEST_ID\",
            \"permission\": \"write\",
            \"status\": \"draft\",
            \"tool\": \"write_file\",
            \"args\": {\"path\": \"/workspace/test.txt\", \"content\": \"test\"}
        }")

    CREATED_PERMISSION_ID=$(echo "$PERMISSION_RES" | jq -r '.id // empty')

    if [ -z "$CREATED_PERMISSION_ID" ]; then
        echo "❌ FAILED: Could not create permission"
        echo "Response: $PERMISSION_RES"
        return 1
    fi

    echo "✅ Permission created: $CREATED_PERMISSION_ID"

    # Verify permission is in draft status
    PERMISSION_GET=$(curl -s -X GET "$PB_URL/api/collections/permissions/records/$CREATED_PERMISSION_ID" \
        -H "Authorization: $USER_TOKEN")

    STATUS=$(echo "$PERMISSION_GET" | jq -r '.status // empty')

    if [ "$STATUS" = "draft" ]; then
        echo "✅ PASSED: Permission is in draft status"
    else
        echo "❌ FAILED: Permission status is not draft"
        echo "Expected: draft"
        echo "Actual: $STATUS"
        return 1
    fi

    # Authorize the permission
    echo "Authorizing permission..."
    AUTHORIZE_RES=$(curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$CREATED_PERMISSION_ID" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"status": "authorized"}')

    NEW_STATUS=$(echo "$AUTHORIZE_RES" | jq -r '.status // empty')

    if [ "$NEW_STATUS" = "authorized" ]; then
        echo "✅ PASSED: Permission authorized successfully"
    else
        echo "❌ FAILED: Could not authorize permission"
        echo "Expected: authorized"
        echo "Actual: $NEW_STATUS"
        echo "Response: $AUTHORIZE_RES"
        return 1
    fi

    echo "✅ Test 5 PASSED: Permission Request Flow"
}

# ========================================
# Run all tests
# ========================================
run_all_tests() {
    test_ssh_key_registration
    test_ssh_key_sync
    test_ssh_key_deactivation
    test_multiple_ssh_keys
    test_permission_flow

    echo ""
    echo "========================================"
    echo "✅ All Zone F tests passed!"
    echo "========================================"
}

# Run tests
run_all_tests
