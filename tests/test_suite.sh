#!/bin/bash

# PocketCoder Test Suite
# Tests the permission/execution split architecture

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Configuration
POCKETBASE_URL="http://localhost:8090"
GATEWAY_URL="http://localhost:3001"

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

assert_equals() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$actual" = "$expected" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$message"
        log_error "  Expected: $expected"
        log_error "  Got: $actual"
        return 1
    fi
}

assert_not_null() {
    local value="$1"
    local message="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ -n "$value" ] && [ "$value" != "null" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$message"
        log_error "  Value was null or empty"
        return 1
    fi
}

# Cleanup function
cleanup() {
    if [ -n "$AUTH_TOKEN" ]; then
        log_info "Cleaning up test data..."
        
        # Delete test permissions
        curl -s -X DELETE "$POCKETBASE_URL/api/collections/permissions/records" \
            -H "Authorization: Bearer $AUTH_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"filter": "source = \"test-suite\""}' > /dev/null 2>&1 || true
        
        # Delete test executions
        curl -s -X DELETE "$POCKETBASE_URL/api/collections/executions/records" \
            -H "Authorization: Bearer $AUTH_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"filter": "source = \"test-suite\""}' > /dev/null 2>&1 || true
    fi
}

trap cleanup EXIT

# ============================================================================
# SETUP
# ============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         PocketCoder Test Suite - Permission/Execution Split    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

log_info "Setting up test environment..."

# Get agent password from docker
AGENT_PASSWORD=$(docker exec pocketcoder-pocketbase env 2>/dev/null | grep AGENT_PASSWORD | cut -d= -f2)

if [ -z "$AGENT_PASSWORD" ]; then
    log_error "Failed to get agent password from docker"
    exit 1
fi

# Authenticate
log_info "Authenticating as agent..."
AUTH_RESPONSE=$(curl -s -X POST "$POCKETBASE_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{
        \"identity\": \"agent@pocketcoder.local\",
        \"password\": \"$AGENT_PASSWORD\"
    }")

AUTH_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.token')

if [ "$AUTH_TOKEN" = "null" ] || [ -z "$AUTH_TOKEN" ]; then
    log_error "Authentication failed"
    echo "$AUTH_RESPONSE" | jq .
    exit 1
fi

log_success "Authenticated successfully"

# Get admin token for collections API (requires admin access)
ADMIN_PASSWORD=$(docker exec pocketcoder-pocketbase env 2>/dev/null | grep ADMIN_PASSWORD | cut -d= -f2)
ADMIN_AUTH_RESPONSE=$(curl -s -X POST "$POCKETBASE_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{
        \"identity\": \"admin@pocketcoder.local\",
        \"password\": \"$ADMIN_PASSWORD\"
    }")
ADMIN_TOKEN=$(echo "$ADMIN_AUTH_RESPONSE" | jq -r '.token')

echo ""

# ============================================================================
# TEST 1: Permissions Collection Exists
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 1: Permissions Collection Exists"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Try to create a test permission to verify collection exists
TEST_PERM_RESPONSE=$(curl -s -X POST "$POCKETBASE_URL/api/collections/permissions/records" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -d '{
        "opencode_id": "test_collection_check_'$(date +%s)'",
        "session_id": "test",
        "permission": "read",
        "patterns": [],
        "metadata": {},
        "always": [],
        "source": "test-suite",
        "status": "draft",
        "message": "Collection check"
    }')

COLLECTION_CHECK=$(echo "$TEST_PERM_RESPONSE" | jq -r '.id // "null"')

if [ "$COLLECTION_CHECK" != "null" ]; then
    assert_not_null "$COLLECTION_CHECK" "Permissions collection exists"
    # Clean up test record
    curl -s -X DELETE "$POCKETBASE_URL/api/collections/permissions/records/$COLLECTION_CHECK" \
        -H "Authorization: Bearer $AUTH_TOKEN" > /dev/null 2>&1
else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    log_error "Permissions collection exists"
    log_error "  Response: $(echo "$TEST_PERM_RESPONSE" | jq -r '.message // "Unknown error"')"
fi
echo ""

# ============================================================================
# TEST 2: Auto-Authorization for Read Permissions
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 2: Auto-Authorization for Read Permissions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

READ_RESPONSE=$(curl -s -X POST "$POCKETBASE_URL/api/collections/permissions/records" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -d '{
        "opencode_id": "test_read_'$(date +%s)'",
        "session_id": "test_session_001",
        "permission": "read",
        "patterns": ["*.ts", "*.js"],
        "metadata": {},
        "always": [],
        "source": "test-suite",
        "status": "draft",
        "message": "Test read permission"
    }')

READ_ID=$(echo "$READ_RESPONSE" | jq -r '.id')
READ_STATUS=$(echo "$READ_RESPONSE" | jq -r '.status')

assert_not_null "$READ_ID" "Read permission created"
assert_equals "$READ_STATUS" "authorized" "Read permission auto-authorized"
echo ""

# ============================================================================
# TEST 3: Auto-Authorization for Write Permissions
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 3: Auto-Authorization for Write Permissions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WRITE_RESPONSE=$(curl -s -X POST "$POCKETBASE_URL/api/collections/permissions/records" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -d '{
        "opencode_id": "test_write_'$(date +%s)'",
        "session_id": "test_session_001",
        "permission": "edit",
        "patterns": ["src/main.ts"],
        "metadata": {},
        "always": [],
        "source": "test-suite",
        "status": "draft",
        "message": "Test write permission"
    }')

WRITE_ID=$(echo "$WRITE_RESPONSE" | jq -r '.id')
WRITE_STATUS=$(echo "$WRITE_RESPONSE" | jq -r '.status')

assert_not_null "$WRITE_ID" "Write permission created"
assert_equals "$WRITE_STATUS" "authorized" "Write permission auto-authorized"
echo ""

# ============================================================================
# TEST 4: Bash Permissions Stay as Draft
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 4: Bash Permissions Stay as Draft"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

BASH_RESPONSE=$(curl -s -X POST "$POCKETBASE_URL/api/collections/permissions/records" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -d '{
        "opencode_id": "test_bash_'$(date +%s)'",
        "session_id": "test_session_001",
        "permission": "bash",
        "patterns": [],
        "metadata": {"command": "ls -la"},
        "always": [],
        "source": "test-suite",
        "status": "draft",
        "message": "Test bash permission"
    }')

BASH_ID=$(echo "$BASH_RESPONSE" | jq -r '.id')
BASH_STATUS=$(echo "$BASH_RESPONSE" | jq -r '.status')

assert_not_null "$BASH_ID" "Bash permission created"
assert_equals "$BASH_STATUS" "draft" "Bash permission stays as draft"
echo ""

# ============================================================================
# TEST 5: List Permissions by Session
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 5: List Permissions by Session"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

LIST_RESPONSE=$(curl -s -X GET "$POCKETBASE_URL/api/collections/permissions/records?filter=session_id='test_session_001'" \
    -H "Authorization: Bearer $AUTH_TOKEN")

PERMISSION_COUNT=$(echo "$LIST_RESPONSE" | jq '.items | length')

log_info "Found $PERMISSION_COUNT permissions for test_session_001"
assert_not_null "$PERMISSION_COUNT" "Can list permissions by session"
echo ""

# ============================================================================
# TEST 6: Gateway Health Check
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 6: Gateway Health Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

HEALTH_RESPONSE=$(curl -s -X GET "$GATEWAY_URL/health" 2>/dev/null || echo '{"status":"unavailable"}')
HEALTH_STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.status // "unavailable"')

if [ "$HEALTH_STATUS" = "ok" ]; then
    assert_equals "$HEALTH_STATUS" "ok" "Gateway is healthy"
else
    log_warning "Gateway health check failed (expected if dormant)"
    log_info "Response: $HEALTH_STATUS"
fi
echo ""

# ============================================================================
# TEST 7: Commands Collection Exists
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 7: Commands Collection Exists"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Try to list commands to verify collection exists
COMMANDS_RESPONSE=$(curl -s -X GET "$POCKETBASE_URL/api/collections/commands/records" \
    -H "Authorization: Bearer $AUTH_TOKEN")

COMMANDS_CHECK=$(echo "$COMMANDS_RESPONSE" | jq -r '.items // "null"')

if [ "$COMMANDS_CHECK" != "null" ]; then
    assert_not_null "$COMMANDS_CHECK" "Commands collection exists"
else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    log_error "Commands collection exists"
fi
echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                        TEST SUMMARY                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Total Tests:   $TESTS_RUN"
echo "  Passed:        $(printf "${GREEN}%d${NC}" $TESTS_PASSED)"
echo "  Failed:        $(printf "${RED}%d${NC}" $TESTS_FAILED)"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    log_success "All tests passed! 🎉"
    exit 0
else
    log_error "Some tests failed"
    exit 1
fi
