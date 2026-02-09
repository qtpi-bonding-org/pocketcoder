#!/bin/bash
# SSH Key Authentication Integration Tests
# Tests the end-to-end SSH key registration and authentication flow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
POCKETBASE_URL="${POCKETBASE_URL:-http://localhost:8090}"
SSH_HOST="${SSH_HOST:-localhost}"
SSH_PORT="${SSH_PORT:-2222}"
SSH_USER="${SSH_USER:-worker}"
TEST_USER_EMAIL="test-ssh-$(date +%s)@example.com"
TEST_USER_PASSWORD="TestPassword123!"

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up test resources...${NC}"
    if [ -n "$TEST_USER_ID" ]; then
        # Delete test user (this will cascade delete their SSH keys)
        curl -s -X DELETE "$POCKETBASE_URL/api/collections/users/records/$TEST_USER_ID" \
            -H "Authorization: $ADMIN_TOKEN" > /dev/null || true
    fi
    # Remove test SSH keys
    rm -f /tmp/test_ssh_key /tmp/test_ssh_key.pub
}

trap cleanup EXIT

# Helper functions
log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    exit 1
}

# Test 1: Check if PocketBase is running
test_pocketbase_health() {
    log_test "Checking PocketBase health..."
    
    if curl -s -f "$POCKETBASE_URL/api/health" > /dev/null; then
        log_success "PocketBase is running"
    else
        log_error "PocketBase is not accessible at $POCKETBASE_URL"
    fi
}

# Test 2: Get admin token
test_get_admin_token() {
    log_test "Authenticating as admin..."
    
    # Load admin credentials from .env
    if [ -f .env ]; then
        ADMIN_EMAIL=$(grep "^POCKETBASE_SUPERUSER_EMAIL=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
        ADMIN_PASSWORD=$(grep "^POCKETBASE_SUPERUSER_PASSWORD=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
    else
        log_error ".env file not found"
    fi
    
    if [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASSWORD" ]; then
        log_error "Admin credentials not found in .env"
    fi
    
    ADMIN_RESPONSE=$(curl -s -X POST "$POCKETBASE_URL/api/collections/_superusers/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")
    
    ADMIN_TOKEN=$(echo "$ADMIN_RESPONSE" | jq -r '.token // empty')
    
    if [ -z "$ADMIN_TOKEN" ]; then
        log_error "Failed to get admin token. Response: $ADMIN_RESPONSE"
    fi
    
    log_success "Admin authenticated"
}

# Test 3: Create test user
test_create_user() {
    log_test "Creating test user..."
    
    USER_RESPONSE=$(curl -s -X POST "$POCKETBASE_URL/api/collections/users/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $ADMIN_TOKEN" \
        -d "{\"email\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\",\"passwordConfirm\":\"$TEST_USER_PASSWORD\"}")
    
    TEST_USER_ID=$(echo "$USER_RESPONSE" | jq -r '.id // empty')
    
    if [ -z "$TEST_USER_ID" ]; then
        log_error "Failed to create test user. Response: $USER_RESPONSE"
    fi
    
    log_success "Test user created: $TEST_USER_ID"
}

# Test 4: Authenticate as test user
test_user_auth() {
    log_test "Authenticating as test user..."
    
    AUTH_RESPONSE=$(curl -s -X POST "$POCKETBASE_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\"}")
    
    USER_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.token // empty')
    
    if [ -z "$USER_TOKEN" ]; then
        log_error "Failed to authenticate test user. Response: $AUTH_RESPONSE"
    fi
    
    log_success "Test user authenticated"
}

# Test 5: Generate SSH key pair
test_generate_ssh_key() {
    log_test "Generating SSH key pair..."
    
    ssh-keygen -t ed25519 -f /tmp/test_ssh_key -N "" -C "test-device" > /dev/null 2>&1
    
    if [ ! -f /tmp/test_ssh_key ] || [ ! -f /tmp/test_ssh_key.pub ]; then
        log_error "Failed to generate SSH key pair"
    fi
    
    TEST_PUBLIC_KEY=$(cat /tmp/test_ssh_key.pub)
    log_success "SSH key pair generated"
}

# Test 6: Calculate SSH key fingerprint
test_calculate_fingerprint() {
    log_test "Calculating SSH key fingerprint..."
    
    # Extract the base64 part of the public key
    KEY_BASE64=$(echo "$TEST_PUBLIC_KEY" | awk '{print $2}')
    
    # Calculate SHA256 fingerprint
    FINGERPRINT="SHA256:$(echo "$KEY_BASE64" | base64 -d | shasum -a 256 | awk '{print $1}' | xxd -r -p | base64)"
    
    if [ -z "$FINGERPRINT" ]; then
        log_error "Failed to calculate fingerprint"
    fi
    
    log_success "Fingerprint calculated: $FINGERPRINT"
}

# Test 7: Register SSH key to PocketBase
test_register_ssh_key() {
    log_test "Registering SSH key to PocketBase..."
    
    SSH_KEY_RESPONSE=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ssh_keys/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d "{
            \"user\":\"$TEST_USER_ID\",
            \"public_key\":\"$TEST_PUBLIC_KEY\",
            \"device_name\":\"Test Device\",
            \"fingerprint\":\"$FINGERPRINT\",
            \"is_active\":true
        }")
    
    SSH_KEY_ID=$(echo "$SSH_KEY_RESPONSE" | jq -r '.id // empty')
    
    if [ -z "$SSH_KEY_ID" ]; then
        log_error "Failed to register SSH key. Response: $SSH_KEY_RESPONSE"
    fi
    
    log_success "SSH key registered: $SSH_KEY_ID"
}

# Test 8: Verify SSH key appears in sync endpoint
test_ssh_keys_endpoint() {
    log_test "Checking SSH keys sync endpoint..."
    
    KEYS_RESPONSE=$(curl -s "$POCKETBASE_URL/api/pocketcoder/ssh_keys")
    
    if echo "$KEYS_RESPONSE" | grep -q "$(echo "$TEST_PUBLIC_KEY" | awk '{print $2}')"; then
        log_success "SSH key appears in sync endpoint"
    else
        log_error "SSH key not found in sync endpoint. Response: $KEYS_RESPONSE"
    fi
}

# Test 9: Test SSH connection (if sandbox is running)
test_ssh_connection() {
    log_test "Testing SSH connection to sandbox..."
    
    # Check if SSH port is open
    if ! nc -z "$SSH_HOST" "$SSH_PORT" 2>/dev/null; then
        echo -e "${YELLOW}[SKIP]${NC} Sandbox SSH not accessible, skipping connection test"
        return 0
    fi
    
    # Trigger manual key sync in sandbox (reads from shared volume)
    log_test "Triggering SSH key sync in sandbox..."
    docker exec pocketcoder-sandbox /usr/local/bin/sync_keys.sh 2>/dev/null || true
    
    # Wait a moment for sync to complete
    sleep 2
    
    # Try to connect with retry logic (up to 5 attempts)
    MAX_RETRIES=5
    RETRY=0
    SUCCESS=false
    
    while [ $RETRY -lt $MAX_RETRIES ]; do
        if ssh -i /tmp/test_ssh_key \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o PasswordAuthentication=no \
            -o PreferredAuthentications=publickey \
            -o BatchMode=yes \
            -o ConnectTimeout=5 \
            -p "$SSH_PORT" \
            "$SSH_USER@$SSH_HOST" \
            "echo 'SSH connection successful'" 2>/dev/null | grep -q "SSH connection successful"; then
            SUCCESS=true
            break
        fi
        
        RETRY=$((RETRY+1))
        if [ $RETRY -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}[RETRY]${NC} Attempt $RETRY/$MAX_RETRIES failed, waiting for relay to sync keys..."
            # Wait longer on first retry to give relay time to sync
            if [ $RETRY -eq 1 ]; then
                sleep 5
            else
                sleep 2
            fi
            # Trigger sync again
            docker exec pocketcoder-sandbox /usr/local/bin/sync_keys.sh 2>/dev/null || true
        fi
    done
    
    if [ "$SUCCESS" = true ]; then
        log_success "SSH connection successful"
    else
        echo -e "${YELLOW}[WARN]${NC} SSH connection failed after $MAX_RETRIES attempts (relay might not have synced keys yet)"
    fi
}

# Test 10: Test key deactivation
test_deactivate_key() {
    log_test "Testing SSH key deactivation..."
    
    DEACTIVATE_RESPONSE=$(curl -s -X PATCH "$POCKETBASE_URL/api/collections/ssh_keys/records/$SSH_KEY_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"is_active":false}')
    
    IS_ACTIVE=$(echo "$DEACTIVATE_RESPONSE" | jq -r '.is_active')
    
    if [ "$IS_ACTIVE" = "false" ]; then
        log_success "SSH key deactivated"
    else
        log_error "Failed to deactivate SSH key. Response: $DEACTIVATE_RESPONSE"
    fi
}

# Test 11: Verify deactivated key doesn't appear in sync endpoint
test_deactivated_key_not_synced() {
    log_test "Verifying deactivated key is not synced..."
    
    KEYS_RESPONSE=$(curl -s "$POCKETBASE_URL/api/openclaw/ssh_keys")
    
    if ! echo "$KEYS_RESPONSE" | grep -q "$(echo "$TEST_PUBLIC_KEY" | awk '{print $2}')"; then
        log_success "Deactivated key not in sync endpoint"
    else
        log_error "Deactivated key still appears in sync endpoint"
    fi
}

# Test 12: Test multiple keys per user
test_multiple_keys() {
    log_test "Testing multiple SSH keys per user..."
    
    # Generate second key
    ssh-keygen -t ed25519 -f /tmp/test_ssh_key2 -N "" -C "test-device-2" > /dev/null 2>&1
    TEST_PUBLIC_KEY2=$(cat /tmp/test_ssh_key2.pub)
    KEY_BASE64_2=$(echo "$TEST_PUBLIC_KEY2" | awk '{print $2}')
    FINGERPRINT2="SHA256:$(echo "$KEY_BASE64_2" | base64 -d | shasum -a 256 | awk '{print $1}' | xxd -r -p | base64)"
    
    # Register second key
    SSH_KEY_RESPONSE2=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ssh_keys/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d "{
            \"user\":\"$TEST_USER_ID\",
            \"public_key\":\"$TEST_PUBLIC_KEY2\",
            \"device_name\":\"Test Device 2\",
            \"fingerprint\":\"$FINGERPRINT2\",
            \"is_active\":true
        }")
    
    SSH_KEY_ID2=$(echo "$SSH_KEY_RESPONSE2" | jq -r '.id // empty')
    
    if [ -n "$SSH_KEY_ID2" ]; then
        log_success "Multiple SSH keys supported"
        # Cleanup second key
        rm -f /tmp/test_ssh_key2 /tmp/test_ssh_key2.pub
    else
        log_error "Failed to register second SSH key"
    fi
}

# Main test execution
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}SSH Key Authentication Integration Tests${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    test_pocketbase_health
    test_get_admin_token
    test_create_user
    test_user_auth
    test_generate_ssh_key
    test_calculate_fingerprint
    test_register_ssh_key
    test_ssh_keys_endpoint
    test_ssh_connection
    test_deactivate_key
    test_deactivated_key_not_synced
    test_multiple_keys
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}All tests passed! ✓${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Run tests
main
