#!/bin/bash
# SSH Key Deletion/Revocation Test
# Tests that deleted SSH keys are properly removed from authorized_keys

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
POCKETBASE_URL="${POCKETBASE_URL:-http://localhost:8090}"

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

# Main test
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}SSH Key Deletion/Revocation Test${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    log_test "Loading admin credentials..."
    ADMIN_EMAIL=$(grep "^POCKETBASE_SUPERUSER_EMAIL=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
    ADMIN_PASSWORD=$(grep "^POCKETBASE_SUPERUSER_PASSWORD=" .env | cut -d'=' -f2 | tr -d '\r' | xargs)
    
    if [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASSWORD" ]; then
        log_error "Admin credentials not found in .env"
    fi
    
    log_test "Authenticating as admin..."
    ADMIN_TOKEN=$(curl -s -X POST "$POCKETBASE_URL/api/collections/_superusers/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" | jq -r '.token')
    
    if [ -z "$ADMIN_TOKEN" ]; then
        log_error "Failed to get admin token"
    fi
    log_success "Admin authenticated"
    
    log_test "Creating test user..."
    TEST_USER_EMAIL="deletion-test-$(date +%s)@example.com"
    USER_ID=$(curl -s -X POST "$POCKETBASE_URL/api/collections/users/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $ADMIN_TOKEN" \
        -d "{\"email\":\"$TEST_USER_EMAIL\",\"password\":\"Test123!\",\"passwordConfirm\":\"Test123!\"}" | jq -r '.id')
    
    if [ -z "$USER_ID" ]; then
        log_error "Failed to create test user"
    fi
    log_success "Test user created: $USER_ID"
    
    log_test "Authenticating as test user..."
    USER_TOKEN=$(curl -s -X POST "$POCKETBASE_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"$TEST_USER_EMAIL\",\"password\":\"Test123!\"}" | jq -r '.token')
    
    if [ -z "$USER_TOKEN" ]; then
        log_error "Failed to authenticate test user"
    fi
    log_success "Test user authenticated"
    
    log_test "Generating SSH key..."
    rm -f /tmp/deletion_test_key /tmp/deletion_test_key.pub
    ssh-keygen -t ed25519 -f /tmp/deletion_test_key -N "" -C "deletion-test" > /dev/null 2>&1
    PUBLIC_KEY=$(cat /tmp/deletion_test_key.pub)
    KEY_BASE64=$(echo "$PUBLIC_KEY" | awk '{print $2}')
    FINGERPRINT="SHA256:$(echo "$KEY_BASE64" | base64 -d | shasum -a 256 | awk '{print $1}' | xxd -r -p | base64)"
    log_success "SSH key generated"
    
    log_test "Registering SSH key..."
    SSH_KEY_ID=$(curl -s -X POST "$POCKETBASE_URL/api/collections/ssh_keys/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d "{
            \"user\":\"$USER_ID\",
            \"public_key\":\"$PUBLIC_KEY\",
            \"device_name\":\"Deletion Test\",
            \"fingerprint\":\"$FINGERPRINT\",
            \"is_active\":true
        }" | jq -r '.id')
    
    if [ -z "$SSH_KEY_ID" ]; then
        log_error "Failed to register SSH key"
    fi
    log_success "SSH key registered: $SSH_KEY_ID"
    
    log_test "Triggering sandbox sync..."
    docker exec pocketcoder-sandbox /usr/local/bin/sync_keys.sh 2>/dev/null || true
    sleep 2
    
    log_test "Verifying key is present..."
    if docker exec pocketcoder-sandbox grep -q "$KEY_BASE64" /home/worker/.ssh/authorized_keys; then
        log_success "Key is present in authorized_keys"
    else
        log_error "Key not found in authorized_keys (initial check failed)"
    fi
    
    log_test "Deleting SSH key..."
    curl -s -X DELETE "$POCKETBASE_URL/api/collections/ssh_keys/records/$SSH_KEY_ID" \
        -H "Authorization: $USER_TOKEN" > /dev/null
    log_success "SSH key deleted from database"
    
    log_test "Waiting for relay to sync (5 seconds)..."
    sleep 5
    
    log_test "Triggering sandbox sync..."
    docker exec pocketcoder-sandbox /usr/local/bin/sync_keys.sh 2>/dev/null || true
    sleep 2
    
    log_test "Verifying key is removed..."
    if docker exec pocketcoder-sandbox grep -q "$KEY_BASE64" /home/worker/.ssh/authorized_keys 2>/dev/null; then
        log_error "Key still present after deletion!"
    else
        log_success "Key successfully removed from authorized_keys"
    fi
    
    # Cleanup
    echo ""
    log_test "Cleaning up test resources..."
    curl -s -X DELETE "$POCKETBASE_URL/api/collections/users/records/$USER_ID" \
        -H "Authorization: $ADMIN_TOKEN" > /dev/null
    rm -f /tmp/deletion_test_key /tmp/deletion_test_key.pub
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deletion test passed! ✓${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Run test
main
