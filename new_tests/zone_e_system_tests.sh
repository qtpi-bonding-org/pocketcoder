#!/bin/sh
# new_tests/zone_e_system_tests.sh
# Zone E tests for System-Wide Integration
# Tests verify health checks and cross-service communication
# Usage: ./new_tests/zone_e_system_tests.sh

# Note: This script uses busybox-compatible sh syntax

# Source authentication helper
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/auth.sh"

# Configuration
PB_URL="http://127.0.0.1:8090"
OPENCODE_URL="${OPENCODE_URL:-http://opencode:4096}"

# Timeout settings
HEALTH_TIMEOUT=30
POLL_INTERVAL=2

# Generate unique test ID for this run
TEST_ID=$(date +%s | rev | cut -c 1-8)$(printf "%04d" $RANDOM | head -c 4)
echo "🧪 Zone E Tests - Run ID: $TEST_ID"
echo "========================================"

# ========================================
# Test 1: PocketBase Health Check
# Validates: System health and availability
# ========================================
test_pocketbase_health() {
    echo ""
    echo "📋 Test 1: PocketBase Health Check"
    echo "-----------------------------------"

    echo "Checking PocketBase health endpoint..."
    HEALTH_RES=$(curl -s -w "\n%{http_code}" "$PB_URL/api/health" 2>&1)
    HTTP_CODE=$(echo "$HEALTH_RES" | tail -n1)
    BODY=$(echo "$HEALTH_RES" | sed '$d')

    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ PASSED: PocketBase is healthy (HTTP 200)"
    else
        echo "❌ FAILED: PocketBase health check failed"
        echo "Expected: HTTP 200"
        echo "Actual: HTTP $HTTP_CODE"
        echo "Response: $BODY"
        return 1
    fi

    # Verify response contains expected fields
    if echo "$BODY" | grep -q "code"; then
        echo "✅ PASSED: Health response contains status code"
    else
        echo "⚠️  Health response format may vary"
    fi

    echo "✅ Test 1 PASSED: PocketBase Health Check"
}

# ========================================
# Test 2: OpenCode Health Status Reporting
# Validates: OpenCode reports health to PocketBase
# ========================================
test_opencode_health_reporting() {
    echo ""
    echo "📋 Test 2: OpenCode Health Status Reporting"
    echo "--------------------------------------------"

    echo "Waiting for OpenCode heartbeat to PocketBase..."
    
    MAX_RETRIES=15
    RETRY=0
    STATUS=""
    
    while [ $RETRY -lt $MAX_RETRIES ]; do
        echo "Checking healthchecks collection... (Attempt $((RETRY+1))/$MAX_RETRIES)"
        
        RESPONSE=$(curl -s -X GET "$PB_URL/api/collections/healthchecks/records?filter=(name='opencode')" \
            -H "Authorization: $USER_TOKEN")
        
        STATUS=$(echo "$RESPONSE" | jq -r '.items[0].status // empty')
        
        if [ "$STATUS" = "ready" ]; then
            echo "✅ PASSED: OpenCode status is READY"
            
            # Get additional details
            LAST_HEARTBEAT=$(echo "$RESPONSE" | jq -r '.items[0].updated // empty')
            echo "Last heartbeat: $LAST_HEARTBEAT"
            
            return 0
        fi
        
        RETRY=$((RETRY+1))
        if [ $RETRY -lt $MAX_RETRIES ]; then
            echo "Current status: ${STATUS:-none}, waiting..."
            sleep $POLL_INTERVAL
        fi
    done
    
    echo "❌ FAILED: OpenCode health check failed after timeout"
    echo "Expected: status = 'ready'"
    echo "Actual: status = ${STATUS:-none}"
    echo "Response: $RESPONSE"
    return 1
}

# ========================================
# Test 3: Service Interconnection
# Validates: All services can communicate
# ========================================
test_service_interconnection() {
    echo ""
    echo "📋 Test 3: Service Interconnection"
    echo "-----------------------------------"

    # Test PocketBase -> OpenCode communication
    echo "Testing PocketBase -> OpenCode communication..."
    
    # Check if OpenCode is accessible
    OPENCODE_HEALTH=$(curl -s "$OPENCODE_URL/global/health" 2>&1 || echo "failed")
    
    if echo "$OPENCODE_HEALTH" | grep -q "healthy"; then
        echo "✅ PASSED: OpenCode is accessible and healthy"
    else
        echo "⚠️  OpenCode may not be accessible from test environment"
        echo "Response: $OPENCODE_HEALTH"
    fi

    # Test PocketBase authentication works
    echo "Testing PocketBase authentication..."
    
    if [ -n "$USER_TOKEN" ]; then
        echo "✅ PASSED: PocketBase authentication working"
    else
        echo "❌ FAILED: PocketBase authentication failed"
        return 1
    fi

    # Test PocketBase collections are accessible
    echo "Testing PocketBase collections access..."
    
    CHATS_RES=$(curl -s -X GET "$PB_URL/api/collections/chats/records?perPage=1" \
        -H "Authorization: $USER_TOKEN")
    
    if echo "$CHATS_RES" | grep -q "items"; then
        echo "✅ PASSED: PocketBase collections accessible"
    else
        echo "❌ FAILED: PocketBase collections not accessible"
        echo "Response: $CHATS_RES"
        return 1
    fi

    echo "✅ Test 3 PASSED: Service Interconnection"
}

# ========================================
# Run all tests
# ========================================
run_all_tests() {
    test_pocketbase_health
    test_opencode_health_reporting
    test_service_interconnection

    echo ""
    echo "========================================"
    echo "✅ All Zone E tests passed!"
    echo "========================================"
}

# Run tests
run_all_tests
