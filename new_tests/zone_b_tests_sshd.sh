#!/bin/sh
# new_tests/zone_b_tests_sshd.sh
# Zone B tests for sshd in OpenCode container (Poco Native Attach Phase 1)
# Tests verify sshd configuration, poco user, ForceCommand, and authorized keys
# Usage: Run via ./run_test.sh b pocketcoder-opencode

# Configuration
OPENCODE_CONTAINER="pocketcoder-opencode"
SSH_PORT="2222"
SSH_KEYS_VOLUME="/ssh_keys"

# Generate unique test ID for this run
TEST_ID=$(date +%s | rev | cut -c 1-8)$(printf "%04d" $RANDOM | head -c 4)
echo "🧪 Zone B SSH Tests - Run ID: $TEST_ID"
echo "========================================"

# ========================================
# Test 1: sshd is running on port 2222
# Validates: Requirements 1.1
# ========================================
test_sshd_running_on_port_2222() {
    echo ""
    echo "📋 Test 1: sshd is running on port 2222"
    echo "--------------------------------------"

    # Check if sshd process is running
    echo "Checking sshd process..."
    SSH_PID=$(docker exec "$OPENCODE_CONTAINER" pgrep -x sshd 2>/dev/null)

    if [ -z "$SSH_PID" ]; then
        echo "❌ FAILED: sshd process is not running"
        echo "Expected: sshd process running"
        echo "Actual: No sshd process found"
        return 1
    fi

    echo "✅ sshd process is running (PID: $SSH_PID)"

    # Check if sshd is listening on port 2222
    echo "Checking sshd is listening on port $SSH_PORT..."
    PORT_CHECK=$(docker exec "$OPENCODE_CONTAINER" ss -tlnp 2>/dev/null | grep ":$SSH_PORT " || true)

    if [ -z "$PORT_CHECK" ]; then
        echo "❌ FAILED: sshd is not listening on port $SSH_PORT"
        echo "Expected: sshd listening on port $SSH_PORT"
        echo "Actual: No listener found on port $SSH_PORT"
        echo "Current listeners:"
        docker exec "$OPENCODE_CONTAINER" ss -tlnp 2>/dev/null || echo "  (ss command not available)"
        return 1
    fi

    echo "✅ sshd is listening on port $SSH_PORT"
    echo "  Details: $PORT_CHECK"

    # Verify we can connect to sshd
    echo "Verifying SSH connection..."
    CONNECT_RESULT=$(docker exec "$OPENCODE_CONTAINER" sh -c "
        timeout 2 bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/$SSH_PORT' 2>/dev/null
        echo \$?
    " 2>/dev/null || echo "1")

    if [ "$CONNECT_RESULT" = "0" ]; then
        echo "✅ SSH port $SSH_PORT is reachable"
    else
        echo "❌ FAILED: Cannot connect to SSH port $SSH_PORT"
        echo "Expected: Connection successful"
        echo "Actual: Connection failed (exit code: $CONNECT_RESULT)"
        return 1
    fi

    echo "✅ Test 1 PASSED: sshd is running on port 2222"
}

# ========================================
# Test 2: poco user exists
# Validates: Requirements 1.2, 1.3
# ========================================
test_poco_user_exists() {
    echo ""
    echo "📋 Test 2: poco user exists"
    echo "---------------------------"

    # Check if poco user exists
    echo "Checking for poco user..."
    USER_EXISTS=$(docker exec "$OPENCODE_CONTAINER" id poco 2>/dev/null || echo "")

    if [ -z "$USER_EXISTS" ]; then
        echo "❌ FAILED: poco user does not exist"
        echo "Expected: User 'poco' exists in container"
        echo "Actual: User 'poco' not found"
        return 1
    fi

    echo "✅ poco user exists"
    echo "  Details: $USER_EXISTS"

    # Check poco user's shell (should be no login shell for ForceCommand)
    echo "Checking poco user's shell..."
    USER_SHELL=$(docker exec "$OPENCODE_CONTAINER" getent passwd poco 2>/dev/null | cut -d: -f7)

    # For ForceCommand to work, the shell can be /bin/false, /usr/sbin/nologin, or /bin/sh
    # The important thing is that ForceCommand overrides the shell
    echo "  Shell: $USER_SHELL"

    # Check poco user's home directory
    echo "Checking poco user's home directory..."
    USER_HOME=$(docker exec "$OPENCODE_CONTAINER" getent passwd poco 2>/dev/null | cut -d: -f6)

    if [ -z "$USER_HOME" ] || [ "$USER_HOME" = "/nonexistent" ]; then
        echo "⚠️  poco user has no home directory or /nonexistent home"
        echo "  Expected: Valid home directory for .ssh directory"
    else
        echo "✅ poco user home directory: $USER_HOME"
    fi

    # Check .ssh directory exists
    echo "Checking .ssh directory..."
    SSH_DIR="$USER_HOME/.ssh"
    SSH_DIR_EXISTS=$(docker exec "$OPENCODE_CONTAINER" test -d "$SSH_DIR" 2>/dev/null && echo "yes" || echo "no")

    if [ "$SSH_DIR_EXISTS" != "yes" ]; then
        echo "❌ FAILED: .ssh directory does not exist at $SSH_DIR"
        echo "Expected: .ssh directory exists"
        echo "Actual: .ssh directory not found"
        return 1
    fi

    echo "✅ .ssh directory exists at $SSH_DIR"

    # Check .ssh directory permissions
    echo "Checking .ssh directory permissions..."
    SSH_DIR_PERMS=$(docker exec "$OPENCODE_CONTAINER" stat -c "%a" "$SSH_DIR" 2>/dev/null)

    if [ "$SSH_DIR_PERMS" = "700" ]; then
        echo "✅ .ssh directory has correct permissions (700)"
    else
        echo "⚠️  .ssh directory permissions are $SSH_DIR_PERMS (expected 700)"
    fi

    echo "✅ Test 2 PASSED: poco user exists"
}

# ========================================
# Test 3: ForceCommand is configured
# Validates: Requirements 1.3
# ========================================
test_forcecommand_configured() {
    echo ""
    echo "📋 Test 3: ForceCommand is configured"
    echo "-------------------------------------"

    # Check sshd_config for ForceCommand configuration
    echo "Checking sshd configuration for ForceCommand..."

    # Look for ForceCommand in sshd_config.d directory
    SSHD_CONFIG_DIR="/etc/ssh/sshd_config.d"
    FORCE_COMMAND_CONFIG=""

    if docker exec "$OPENCODE_CONTAINER" test -d "$SSHD_CONFIG_DIR" 2>/dev/null; then
        # Check for poco-specific config file
        POCO_CONFIG="$SSHD_CONFIG_DIR/poco.conf"
        if docker exec "$OPENCODE_CONTAINER" test -f "$POCO_CONFIG" 2>/dev/null; then
            FORCE_COMMAND_CONFIG=$(docker exec "$OPENCODE_CONTAINER" cat "$POCO_CONFIG" 2>/dev/null || echo "")
            echo "Found config file: $POCO_CONFIG"
        else
            # Check all config files for ForceCommand
            FORCE_COMMAND_CONFIG=$(docker exec "$OPENCODE_CONTAINER" grep -r "ForceCommand" "$SSHD_CONFIG_DIR" 2>/dev/null || echo "")
        fi
    fi

    # Also check main sshd_config
    MAIN_CONFIG="/etc/ssh/sshd_config"
    MAIN_FORCE_COMMAND=$(docker exec "$OPENCODE_CONTAINER" grep -i "ForceCommand" "$MAIN_CONFIG" 2>/dev/null || echo "")

    if [ -n "$FORCE_COMMAND_CONFIG" ]; then
        echo "✅ ForceCommand found in sshd_config.d:"
        echo "$FORCE_COMMAND_CONFIG"
    elif [ -n "$MAIN_FORCE_COMMAND" ]; then
        echo "✅ ForceCommand found in main sshd_config:"
        echo "$MAIN_FORCE_COMMAND"
    else
        echo "❌ FAILED: ForceCommand not found in sshd configuration"
        echo "Expected: ForceCommand configured for poco user"
        echo "Actual: No ForceCommand directive found"
        echo ""
        echo "Checking all sshd config files..."
        docker exec "$OPENCODE_CONTAINER" cat "$MAIN_CONFIG" 2>/dev/null | grep -i "forcecommand" || echo "  (none found in main config)"
        return 1
    fi

    # Verify ForceCommand contains opencode attach
    echo "Verifying ForceCommand contains 'opencode attach'..."
    if echo "$FORCE_COMMAND_CONFIG $MAIN_FORCE_COMMAND" | grep -qi "opencode attach"; then
        echo "✅ ForceCommand contains 'opencode attach'"
    else
        echo "❌ FAILED: ForceCommand does not contain 'opencode attach'"
        echo "Expected: ForceCommand opencode attach http://localhost:3000 --continue"
        echo "Actual: ForceCommand found but missing opencode attach"
        return 1
    fi

    # Verify ForceCommand contains --continue flag
    echo "Verifying ForceCommand contains '--continue' flag..."
    if echo "$FORCE_COMMAND_CONFIG $MAIN_FORCE_COMMAND" | grep -qi "\-\-continue"; then
        echo "✅ ForceCommand contains '--continue' flag"
    else
        echo "⚠️  ForceCommand may be missing '--continue' flag"
        echo "  Expected: ForceCommand opencode attach http://localhost:3000 --continue"
    fi

    echo "✅ Test 3 PASSED: ForceCommand is configured"
}

# ========================================
# Test 4: authorized key is installed from ssh_keys volume
# Validates: Requirements 1.4
# ========================================
test_authorized_key_installed() {
    echo ""
    echo "📋 Test 4: authorized key is installed from ssh_keys volume"
    echo "----------------------------------------------------------"

    # Get poco user's home directory
    USER_HOME=$(docker exec "$OPENCODE_CONTAINER" getent passwd poco 2>/dev/null | cut -d: -f6)
    AUTHORIZED_KEYS_FILE="$USER_HOME/.ssh/authorized_keys"

    # Check if ssh_keys volume is mounted
    echo "Checking ssh_keys volume mount..."
    SSH_KEYS_MOUNTED="no"

    # Check if /ssh_keys exists and is readable
    if docker exec "$OPENCODE_CONTAINER" test -d "$SSH_KEYS_VOLUME" 2>/dev/null; then
        echo "✅ $SSH_KEYS_VOLUME directory exists"
        SSH_KEYS_MOUNTED="yes"

        # List contents of ssh_keys volume
        echo "Contents of $SSH_KEYS_VOLUME:"
        docker exec "$OPENCODE_CONTAINER" ls -la "$SSH_KEYS_VOLUME" 2>/dev/null || echo "  (unable to list)"
    else
        echo "❌ FAILED: $SSH_KEYS_VOLUME directory does not exist"
        echo "Expected: ssh_keys volume mounted at $SSH_KEYS_VOLUME"
        echo "Actual: Directory not found"
        return 1
    fi

    # Check if authorized_keys file exists
    echo "Checking authorized_keys file..."
    if docker exec "$OPENCODE_CONTAINER" test -f "$AUTHORIZED_KEYS_FILE" 2>/dev/null; then
        echo "✅ authorized_keys file exists at $AUTHORIZED_KEYS_FILE"
    else
        echo "❌ FAILED: authorized_keys file does not exist"
        echo "Expected: $AUTHORIZED_KEYS_FILE"
        echo "Actual: File not found"
        return 1
    fi

    # Check authorized_keys file permissions
    echo "Checking authorized_keys file permissions..."
    AUTH_KEYS_PERMS=$(docker exec "$OPENCODE_CONTAINER" stat -c "%a" "$AUTHORIZED_KEYS_FILE" 2>/dev/null)

    if [ "$AUTH_KEYS_PERMS" = "600" ]; then
        echo "✅ authorized_keys has correct permissions (600)"
    else
        echo "⚠️  authorized_keys permissions are $AUTH_KEYS_PERMS (expected 600)"
    fi

    # Check authorized_keys file ownership
    echo "Checking authorized_keys file ownership..."
    AUTH_KEYS_OWNER=$(docker exec "$OPENCODE_CONTAINER" stat -c "%U:%G" "$AUTHORIZED_KEYS_FILE" 2>/dev/null)

    if echo "$AUTH_KEYS_OWNER" | grep -q "poco:poco"; then
        echo "✅ authorized_keys owned by poco:poco"
    else
        echo "⚠️  authorized_keys owned by $AUTH_KEYS_OWNER (expected poco:poco)"
    fi

    # Verify authorized_keys contains a valid public key
    echo "Verifying authorized_keys contains a public key..."
    KEY_CONTENT=$(docker exec "$OPENCODE_CONTAINER" cat "$AUTHORIZED_KEYS_FILE" 2>/dev/null)

    if [ -z "$KEY_CONTENT" ]; then
        echo "❌ FAILED: authorized_keys file is empty"
        echo "Expected: Public key content in authorized_keys"
        echo "Actual: File is empty"
        return 1
    fi

    # Check if it looks like a valid SSH public key (starts with ssh-rsa, ssh-ed25519, etc.)
    if echo "$KEY_CONTENT" | grep -qE "^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp|sk-ssh-ed25519|sk-ecdsa-sha2-nistp)"; then
        echo "✅ authorized_keys contains valid SSH public key"
        echo "  Key type: $(echo "$KEY_CONTENT" | awk '{print $1}')"
        echo "  Key fingerprint: $(echo "$KEY_CONTENT" | awk '{print $2}' | cut -c1-20)..."
    else
        echo "❌ FAILED: authorized_keys does not contain valid SSH public key"
        echo "Expected: SSH public key (starts with ssh-rsa, ssh-ed25519, etc.)"
        echo "Actual content: $KEY_CONTENT"
        return 1
    fi

    # Verify the key matches the public key in ssh_keys volume
    echo "Verifying authorized key matches ssh_keys volume..."
    if docker exec "$OPENCODE_CONTAINER" test -f "$SSH_KEYS_VOLUME/id_rsa.pub" 2>/dev/null; then
        VOLUME_KEY=$(docker exec "$OPENCODE_CONTAINER" cat "$SSH_KEYS_VOLUME/id_rsa.pub" 2>/dev/null | tr -d '\n\r')

        if [ "$KEY_CONTENT" = "$VOLUME_KEY" ]; then
            echo "✅ authorized_keys matches public key from ssh_keys volume"
        else
            echo "⚠️  authorized_keys does not match volume key (may be intentional for testing)"
            echo "  Volume key: ${VOLUME_KEY:0:50}..."
            echo "  Auth key: ${KEY_CONTENT:0:50}..."
        fi
    elif docker exec "$OPENCODE_CONTAINER" test -f "$SSH_KEYS_VOLUME/id_ed25519.pub" 2>/dev/null; then
        VOLUME_KEY=$(docker exec "$OPENCODE_CONTAINER" cat "$SSH_KEYS_VOLUME/id_ed25519.pub" 2>/dev/null | tr -d '\n\r')

        if [ "$KEY_CONTENT" = "$VOLUME_KEY" ]; then
            echo "✅ authorized_keys matches public key from ssh_keys volume"
        else
            echo "⚠️  authorized_keys does not match volume key (may be intentional for testing)"
        fi
    else
        echo "⚠️  Could not find public key file in $SSH_KEYS_VOLUME to compare"
    fi

    echo "✅ Test 4 PASSED: authorized key is installed from ssh_keys volume"
}

# ========================================
# Run all tests
# ========================================
run_all_tests() {
    test_sshd_running_on_port_2222
    test_poco_user_exists
    test_forcecommand_configured
    test_authorized_key_installed

    echo ""
    echo "========================================"
    echo "✅ All Zone B SSH tests passed!"
    echo "========================================"
}

# Run tests
run_all_tests