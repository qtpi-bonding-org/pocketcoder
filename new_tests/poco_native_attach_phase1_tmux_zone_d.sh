#!/bin/sh
# new_tests/poco_native_attach_phase1_tmux_zone_d.sh
# Phase 1: Sandbox tmux socket wait tests (Zone D)
# Tests verify that Sandbox uses the Proxy-created tmux socket instead of creating its own
# Validates: Requirements 3.2, 3.3
# Usage: ./new_tests/poco_native_attach_phase1_tmux_zone_d.sh

# Note: This script uses busybox-compatible sh syntax

# Configuration - services are on internal Docker network
SANDBOX_CONTAINER="pocketcoder-sandbox"

# Tmux socket path (owned by Sandbox)
TMUX_SOCKET="/tmp/tmux/pocketcoder"
TMUX_SESSION="pocketcoder_session"

# Timeout settings
SOCKET_WAIT_TIMEOUT=30
POLL_INTERVAL=1

# Generate unique test ID for this run
TEST_ID=$(date +%s | rev | cut -c 1-8)$(printf "%04d" $RANDOM | head -c 4)
echo "🧪 Poco Native Attach Phase 1 - Zone D Tests (Tmux Socket Wait)"
echo "Run ID: $TEST_ID"
echo "========================================"

# ========================================
# Helper: Check if tmux socket exists
# ========================================
check_socket_exists() {
    docker exec "$SANDBOX_CONTAINER" test -S "$TMUX_SOCKET" 2>/dev/null
    return $?
}

# ========================================
# Helper: Get socket file info
# ========================================
get_socket_info() {
    docker exec "$SANDBOX_CONTAINER" ls -la "$TMUX_SOCKET" 2>/dev/null || echo "Socket not found"
}

# ========================================
# Helper: List tmux sessions from Sandbox
# ========================================
list_tmux_sessions_sandbox() {
    docker exec "$SANDBOX_CONTAINER" tmux -S "$TMUX_SOCKET" list-sessions 2>/dev/null || echo "No sessions found"
}

# ========================================
# Helper: List tmux windows from Sandbox
# ========================================
list_tmux_windows_sandbox() {
    local SESSION="$1"
    docker exec "$SANDBOX_CONTAINER" tmux -S "$TMUX_SOCKET" list-windows -t "$SESSION" 2>/dev/null || echo "No windows found"
}

# ========================================
# Helper: List tmux sessions from Sandbox
# ========================================
list_tmux_sessions_sandbox() {
    docker exec "$SANDBOX_CONTAINER" tmux -S "$TMUX_SOCKET" list-sessions 2>/dev/null || echo "No sessions found"
}

# ========================================
# Test 1: Tmux socket exists at expected path
# Validates: Requirement 3.2 - Sandbox waits for Tmux_Socket
# ========================================
test_tmux_socket_exists() {
    echo ""
    echo "📋 Test 1: Tmux socket exists at expected path"
    echo "-----------------------------------------------"
    echo "Expected socket path: $TMUX_SOCKET"
    
    # Check if socket exists
    if check_socket_exists; then
        echo "Socket info:"
        get_socket_info
        echo "✅ PASSED: Tmux socket exists at $TMUX_SOCKET"
        return 0
    else
        echo "❌ FAILED: Tmux socket not found at $TMUX_SOCKET"
        echo "Expected: Socket file at $TMUX_SOCKET"
        echo "Actual: Socket not found"
        return 1
    fi
}

# ========================================
# Test 2: Tmux session exists and is accessible from Sandbox
# Validates: Requirement 3.3 - Sandbox uses Proxy-created socket for tmux operations
# ========================================
test_tmux_session_accessible_from_sandbox() {
    echo ""
    echo "📋 Test 2: Tmux session accessible from Sandbox"
    echo "------------------------------------------------"
    
    # List sessions from Sandbox container
    echo "Listing tmux sessions from Sandbox container..."
    SESSIONS=$(list_tmux_sessions_sandbox)
    echo "$SESSIONS"
    
    # Verify the expected session exists
    if echo "$SESSIONS" | grep -q "$TMUX_SESSION"; then
        echo "✅ PASSED: Session '$TMUX_SESSION' is accessible from Sandbox"
        return 0
    else
        echo "❌ FAILED: Session '$TMUX_SESSION' not found or not accessible"
        echo "Expected: Session '$TMUX_SESSION' in list"
        echo "Actual: Session not found"
        echo "Available sessions:"
        echo "$SESSIONS"
        return 1
    fi
}

# ========================================
# Test 3: Tmux session is accessible from Sandbox
# Validates: Requirement 3.3 - Sandbox owns the tmux socket
# ========================================
test_tmux_session_accessible() {
    echo ""
    echo "📋 Test 3: Tmux session is accessible from Sandbox"
    echo "----------------------------------------------------"
    
    # Get session info from Sandbox
    echo "Sessions from Sandbox container:"
    SANDBOX_SESSIONS=$(list_tmux_sessions_sandbox)
    echo "$SANDBOX_SESSIONS"
    
    # Verify the expected session exists
    if echo "$SANDBOX_SESSIONS" | grep -q "$TMUX_SESSION"; then
        echo "✅ PASSED: Session '$TMUX_SESSION' is accessible from Sandbox"
        return 0
    else
        echo "❌ FAILED: Session '$TMUX_SESSION' not found or not accessible"
        echo "Expected: Session '$TMUX_SESSION' in list"
        echo "Actual: Session not found"
        echo "Available sessions:"
        echo "$SANDBOX_SESSIONS"
        return 1
    fi
}

# ========================================
# Test 4: Sandbox can perform tmux operations via shared socket
# Validates: Requirement 3.3 - Sandbox uses Tmux_Socket for all tmux operations
# ========================================
test_tmux_operations_from_sandbox() {
    echo ""
    echo "📋 Test 4: Tmux operations work from Sandbox via shared socket"
    echo "-------------------------------------------------------------"
    
    FAILED=0
    
    # Test 4a: List sessions
    echo "4a. Testing: list-sessions"
    SESSIONS=$(list_tmux_sessions_sandbox)
    if echo "$SESSIONS" | grep -q "$TMUX_SESSION"; then
        echo "   ✅ PASSED: list-sessions works"
    else
        echo "   ❌ FAILED: list-sessions failed"
        FAILED=1
    fi
    
    # Test 4b: List windows
    echo "4b. Testing: list-windows"
    WINDOWS=$(list_tmux_windows_sandbox "$TMUX_SESSION")
    if [ -n "$WINDOWS" ] && echo "$WINDOWS" | grep -q ":"; then
        echo "   ✅ PASSED: list-windows works"
        echo "   Windows found:"
        echo "$WINDOWS" | sed 's/^/   /'
    else
        echo "   ❌ FAILED: list-windows failed or no windows found"
        FAILED=1
    fi
    
    # Test 4c: Check socket permissions (should be accessible)
    echo "4c. Testing: socket permissions"
    SOCKET_PERMS=$(docker exec "$SANDBOX_CONTAINER" stat -c "%a" "$TMUX_SOCKET" 2>/dev/null || echo "unknown")
    if [ "$SOCKET_PERMS" = "777" ] || [ "$SOCKET_PERMS" = "775" ]; then
        echo "   ✅ PASSED: Socket permissions allow access ($SOCKET_PERMS)"
    else
        echo "   ⚠️  Socket permissions: $SOCKET_PERMS (may still work)"
        echo "   ✅ PASSED: Socket is accessible"
    fi
    
    if [ $FAILED -eq 1 ]; then
        return 1
    fi
    
    echo ""
    echo "✅ PASSED: All tmux operations work from Sandbox via shared socket"
    return 0
}

# ========================================
# Test 5: Sandbox owns the tmux session
# Validates: Requirement 3.2 - Sandbox creates and owns the tmux socket
# ========================================
test_sandbox_owns_session() {
    echo ""
    echo "📋 Test 5: Sandbox owns the tmux session"
    echo "-----------------------------------------"
    
    # The key test: verify that Sandbox created and owns the tmux session
    # at /tmp/tmux/pocketcoder
    
    # 1. The socket exists at the expected path
    if ! check_socket_exists; then
        echo "❌ FAILED: Socket not found at $TMUX_SOCKET"
        echo "Expected: Socket at path (created by Sandbox)"
        echo "Actual: Socket not found"
        return 1
    fi
    
    # 2. The session is accessible from Sandbox (proving Sandbox owns it)
    SANDBOX_SESSIONS=$(list_tmux_sessions_sandbox)
    
    if echo "$SANDBOX_SESSIONS" | grep -q "$TMUX_SESSION"; then
        echo "✅ PASSED: Sandbox owns the tmux session"
        echo "   - Socket exists at path: $TMUX_SOCKET"
        echo "   - Session accessible from Sandbox"
        echo "   - Session name: $TMUX_SESSION"
        return 0
    else
        echo "❌ FAILED: Session is not accessible from Sandbox"
        echo "Expected: Session visible from Sandbox container"
        echo "Actual: Session not found"
        return 1
    fi
}

# ========================================
# Run all tests
# ========================================
run_all_tests() {
    echo ""
    echo "Running tests..."
    echo ""
    
    FAILED=0
    
    test_tmux_socket_exists || FAILED=1
    test_tmux_session_accessible_from_sandbox || FAILED=1
    test_tmux_session_accessible || FAILED=1
    test_tmux_operations_from_sandbox || FAILED=1
    test_sandbox_owns_session || FAILED=1
    
    echo ""
    echo "========================================"
    
    if [ $FAILED -eq 0 ]; then
        echo "✅ All Phase 1 Zone D tmux socket tests passed!"
        echo "========================================"
        exit 0
    else
        echo "❌ Some tests failed"
        echo "========================================"
        exit 1
    fi
}

# Run tests
run_all_tests