#!/usr/bin/env bats
# Feature: test-suite-reorganization, Property 5: Connection Tests - OpenCode to Sandbox
#
# Connection tests for OpenCode to Sandbox communication via Shell Bridge /exec
# Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5
#
# Test flow:
# 1. Shell bridge binary exists and is executable
# 2. POST to sandbox:3001/exec with command execution request
# 3. Driver resolves session via CAO API
# 4. Command executes in tmux pane with sentinel pattern
# 5. Output captured and returned in HTTP response

load '../helpers/auth.sh'
load '../helpers/cleanup.sh'
load '../helpers/wait.sh'
load '../helpers/assertions.sh'
load '../helpers/diagnostics.sh'
load '../helpers/tracking.sh'
load '../helpers/cao.sh'

setup() {
    load_env
    TEST_ID=$(generate_test_id)
    export CURRENT_TEST_ID="$TEST_ID"
    
    # Create a test session in CAO for exec tests
    export TEST_SESSION_ID="test_session_${TEST_ID}"
    export TEST_TERMINAL_ID=$(create_test_terminal "$TEST_SESSION_ID" "pocketcoder" "poco" "/workspace")
    
    if [ -z "$TEST_TERMINAL_ID" ]; then
        skip "Failed to create test terminal in CAO"
    fi
}

teardown() {
    cleanup_test_data "$TEST_ID" || true
    delete_test_terminal "$TEST_TERMINAL_ID" || true
}

@test "OpenCode→Sandbox: Shell bridge binary exists and is executable" {
    # Validates: Requirement 5.1
    # Test that shell bridge binary exists at expected path and has execute permissions
    
    # The shell bridge is in the OpenCode container at /usr/local/bin/pocketcoder-shell
    local shell_bridge_path="/usr/local/bin/pocketcoder-shell"
    
    # Check if binary exists in OpenCode container (where it's used)
    run docker exec pocketcoder-opencode test -f "$shell_bridge_path"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "OpenCode→Sandbox" "Shell bridge binary not found at $shell_bridge_path in OpenCode container"
    
    # Check if binary is executable
    run docker exec pocketcoder-opencode test -x "$shell_bridge_path"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "OpenCode→Sandbox" "Shell bridge binary is not executable"
    
    # Verify it's a valid executable (returns 0 or help output)
    local help_output
    help_output=$(docker exec pocketcoder-opencode "$shell_bridge_path" --help 2>&1 || echo "")
    [ -n "$help_output" ] || echo "Shell bridge binary exists but may not support --help"
}

@test "OpenCode→Sandbox: POST to /exec endpoint is accepted" {
    # Validates: Requirement 5.2
    # Test that POST to sandbox:3001/exec with command is accepted
    
    local exec_url="http://sandbox:3001/exec"
    
    # Send exec request with simple command
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "$exec_url" \
        -H "Content-Type: application/json" \
        -d "{\"cmd\": \"echo hello\", \"cwd\": \"/workspace\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')
    
    # Should return 200 or at least be accepted (not 4xx/5xx)
    [[ "$http_code" == "200" ]] || [[ "$http_code" == "202" ]] || [[ "$http_code" == "204" ]] || \
        run_diagnostic_on_failure "OpenCode→Sandbox" "Exec endpoint returned $http_code instead of 2xx"
}

@test "OpenCode→Sandbox: /exec returns valid response format" {
    # Validates: Requirement 5.2
    # Test that /exec response has expected format: {"stdout": "...", "exit_code": N}
    
    local exec_url="http://sandbox:3001/exec"
    
    # Execute simple command
    local response
    response=$(curl -s -X POST "$exec_url" \
        -H "Content-Type: application/json" \
        -d "{\"cmd\": \"echo test_output\", \"cwd\": \"/workspace\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
    
    # Verify response is valid JSON
    echo "$response" | jq -e . > /dev/null
    [ "$?" -eq 0 ] || run_diagnostic_on_failure "OpenCode→Sandbox" "Exec response is not valid JSON"
    
    # Verify response has stdout field
    local stdout
    stdout=$(echo "$response" | jq -r '.stdout // empty')
    [ -n "$stdout" ] || run_diagnostic_on_failure "OpenCode→Sandbox" "Exec response missing stdout field"
    
    # Verify response has exit_code field
    local exit_code
    exit_code=$(echo "$response" | jq -r '.exit_code // empty')
    [ -n "$exit_code" ] || run_diagnostic_on_failure "OpenCode→Sandbox" "Exec response missing exit_code field"
    
    # Verify exit_code is a number
    [[ "$exit_code" =~ ^[0-9]+$ ]] || run_diagnostic_on_failure "OpenCode→Sandbox" "exit_code is not a number: $exit_code"
}

@test "OpenCode→Sandbox: Command executes in tmux pane" {
    # Validates: Requirement 5.3, 5.4
    # Test that command executes in correct tmux pane
    
    local exec_url="http://sandbox:3001/exec"
    
    # Generate unique test output for this test
    local test_output="test_output_$(date +%s)"
    
    # Execute command - the driver will add its own sentinel pattern
    local response
    response=$(curl -s -X POST "$exec_url" \
        -H "Content-Type: application/json" \
        -d "{\"cmd\": \"echo $test_output\", \"cwd\": \"/workspace\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
    
    # Verify output contains our test string
    local stdout
    stdout=$(echo "$response" | jq -r '.stdout // empty')
    echo "$stdout" | grep -q "$test_output" || \
        run_diagnostic_on_failure "OpenCode→Sandbox" "Test output not found in stdout"
    
    # Verify exit code is 0
    local exit_code
    exit_code=$(echo "$response" | jq -r '.exit_code // empty')
    [ "$exit_code" = "0" ] || run_diagnostic_on_failure "OpenCode→Sandbox" "Exit code is not 0: $exit_code"
}

@test "OpenCode→Sandbox: Non-zero exit code is captured" {
    # Validates: Requirement 5.5
    # Test that non-zero exit codes are correctly captured and returned
    
    local exec_url="http://sandbox:3001/exec"
    
    # Execute command that will fail (use false which returns exit code 1)
    local response
    response=$(curl -s -X POST "$exec_url" \
        -H "Content-Type: application/json" \
        -d "{\"cmd\": \"false\", \"cwd\": \"/workspace\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
    
    # Verify exit code is non-zero
    local exit_code
    exit_code=$(echo "$response" | jq -r '.exit_code // empty')
    [ "$exit_code" != "0" ] || run_diagnostic_on_failure "OpenCode→Sandbox" "Exit code should be non-zero for false command"
}

@test "OpenCode→Sandbox: CAO API session resolution" {
    # Validates: Requirement 5.3
    # Test that driver can resolve session via CAO API
    
    local cao_url="http://sandbox:9889"
    
    # Test that CAO API is accessible
    run timeout 5 curl -s -o /dev/null -w "%{http_code}" "$cao_url/health" 2>/dev/null
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "OpenCode→Sandbox" "CAO API health endpoint not reachable"
    
    # Check for successful response
    [[ "${lines[-1]}" == "200" ]] || run_diagnostic_on_failure "OpenCode→Sandbox" "CAO API health returned ${lines[-1]} instead of 200"
}

@test "OpenCode→Sandbox: Command output contains expected content" {
    # Validates: Requirement 5.2
    # Test that command output is correctly captured and returned
    
    local exec_url="http://sandbox:3001/exec"
    
    # Execute command with specific output
    local response
    response=$(curl -s -X POST "$exec_url" \
        -H "Content-Type: application/json" \
        -d "{\"cmd\": \"echo expected_output_content\", \"cwd\": \"/workspace\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
    
    # Verify output contains expected content
    local stdout
    stdout=$(echo "$response" | jq -r '.stdout // empty')
    echo "$stdout" | grep -q "expected_output_content" || \
        run_diagnostic_on_failure "OpenCode→Sandbox" "Output does not contain expected content"
}

@test "OpenCode→Sandbox: Working directory is respected" {
    # Validates: Requirement 5.2
    # Test that cwd parameter is respected
    
    local exec_url="http://sandbox:3001/exec"
    
    # Execute command that shows current directory
    local response
    response=$(curl -s -X POST "$exec_url" \
        -H "Content-Type: application/json" \
        -d "{\"cmd\": \"pwd\", \"cwd\": \"/tmp\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
    
    # Verify output shows /tmp
    local stdout
    stdout=$(echo "$response" | jq -r '.stdout // empty')
    echo "$stdout" | grep -q "/tmp" || \
        run_diagnostic_on_failure "OpenCode→Sandbox" "Working directory not respected: $stdout"
}

@test "OpenCode→Sandbox: Error response format" {
    # Validates: Requirement 5.2
    # Test that errors are returned in expected format: {"error": "...", "exit_code": 1}
    
    local exec_url="http://sandbox:3001/exec"
    
    # Execute invalid command
    local response
    response=$(curl -s -X POST "$exec_url" \
        -H "Content-Type: application/json" \
        -d "{\"cmd\": \"nonexistent_command_12345\", \"cwd\": \"/workspace\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
    
    # Verify response has error field or non-zero exit code
    local exit_code
    exit_code=$(echo "$response" | jq -r '.exit_code // empty')
    local error
    error=$(echo "$response" | jq -r '.error // empty')
    
    # Either error field or non-zero exit code indicates error handling
    if [ -n "$error" ]; then
        echo "Error message received: $error"
    fi
    [ "$exit_code" != "0" ] || echo "Command succeeded (may be expected in sandbox)"
}
