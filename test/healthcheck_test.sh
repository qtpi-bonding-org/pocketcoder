#!/bin/bash
# Healthcheck Integration Test
# Verifies that the relay correctly reports OpenCode health to PocketBase

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

# Test 3: Verify OpenCode status is 'ready'
test_opencode_health() {
    log_test "Verifying OpenCode health status in PocketBase..."
    
    # Wait for status to become 'ready' (it might take a few seconds for first heartbeat)
    MAX_RETRIES=15
    RETRY=0
    STATUS=""
    
    while [ $RETRY -lt $MAX_RETRIES ]; do
        RESPONSE=$(curl -s -X GET "$POCKETBASE_URL/api/collections/healthchecks/records?filter=(name='opencode')" \
            -H "Authorization: $ADMIN_TOKEN")
        
        STATUS=$(echo "$RESPONSE" | jq -r '.items[0].status // empty')
        
        if [ "$STATUS" = "ready" ]; then
            log_success "OpenCode status is READY"
            return 0
        fi
        
        RETRY=$((RETRY+1))
        echo -e "${YELLOW}Waiting for OpenCode heartbeat... ($RETRY/$MAX_RETRIES) Current status: ${STATUS:-none}${NC}"
        sleep 2
    done
    
    log_error "OpenCode health check failed. Final status: $STATUS"
}

# Main test execution
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Healthcheck Integration Test${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    test_pocketbase_health
    test_get_admin_token
    test_opencode_health
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Healthcheck test passed! ✓${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Run tests
main
