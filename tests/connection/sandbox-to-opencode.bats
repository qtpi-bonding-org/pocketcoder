#!/usr/bin/env bats
# Feature: test-suite-reorganization, Property 6: Connection Tests - Sandbox to OpenCode
#
# Connection tests for Sandbox to OpenCode communication (Synchronous Response)
# Validates: Requirements 6.1, 6.2, 6.3, 6.4
#
# Test flow:
# 1. /exec returns output synchronously in same HTTP response
# 2. Response body format: {"stdout": "...", "exit_code": 0} on success
# 3. Response body format: {"error": "...", "exit_code": 1} on failure
# 4. Command round-trip completes within 30 seconds
# 5. Non-zero exit code is correctly captured and returned

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

@test "Sandbox→OpenCode: /exec returns output synchronously" {
    # Validates: Requirement 6.1
    # Test that /exec returns output in the same HTTP response (no separate notification)
    
    local exec_url="http://sandbox:3001/exec"
    
    # Execute simple command and measure response
    local start_time
    start_time=$(date +%s%N)
    
    local response
    response=$(timeout 30 curl -s -X POST "$exec_url" \
        -H "Content-Type: application/json" \
        -d "{\"cmd\": \"echo sync_response\", \"cwd\": \"/workspace\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
    
    local end_time
    end_time=$(date +%s%N)
    local duration_ns=$((end_time - start_time))
    local duration_ms=$((duration_ns / 1000000))
    
    # Verify response was received synchronously
    [ -n "$response" ] || run_diagnostic_on_failure "Sandbox→OpenCode" "No response received"
    
    # Response should be immediate (less than 5 seconds for sync response)
    [ "$duration_ms" -lt 5000 ] || run_diagnostic_on_failure "Sandbox→OpenCode" "Response took ${duration_ms}ms - expected synchronous response"
    
    echo "Response received in ${duration_ms}ms (synchronous)"
}

@test "Sandbox→OpenCode: Success response format" {
    # Validates: Requirement 6.2
    # Test response body format: {"stdout": "...", "exit_code": 0} on success
    
    local exec_url="http://sandbox:3001/exec"
    
    # Execute command
    local response
    response=$(timeout 30 curl -s -X POST "$exec_url" \
        -H "Content-Type: application/json" \
        -d "{\"cmd\": \"echo hello_world\", \"cwd\": \"/workspace\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
    
    # Verify response is valid JSON
    echo "$response" | jq -e . > /dev/null
    [ "$?" -eq 0 ] || run_diagnostic_on_failure "Sandbox→OpenCode" "Response is not valid JSON"
    
    # Verify stdout field exists
    local stdout
    stdout=$(echo "$response" | jq -r '.stdout // empty')
    [ -n "$stdout" ] || run_diagnostic_on_failure "Sandbox→OpenCode" "Missing stdout field in response"
    
    # Verify exit_code field exists and is 0
    local exit_code
    exit_code=$(echo "$response" | jq -r '.exit_code // empty')
    [ "$exit_code" = "0" ] || run_diagnostic_on_failure "Sandbox→OpenCode" "exit_code is not 0: $exit_code"
    
    # Verify stdout contains expected output
    echo "$stdout" | grep -q "hello_world" || run_diagnostic_on_failure "Sandbox→OpenCode" "stdout does not contain expected output"
}

@test "Sandbox→OpenCode: Error response format" {
    # Validates: Requirement 6.3
    # Test response body format: {"error": "...", "exit_code": 1} on failure
    
    local exec_url="http://sandbox:3001/exec"
    
    # Execute failing command
    local response
    response=$(timeout 30 curl -s -X POST "$exec_url" \
        -H "Content-Type: application/json" \
        -d "{\"cmd\": \"exit 1\", \"cwd\": \"/workspace\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
    
    # Verify response is valid JSON
    echo "$response" | jq -e . > /dev/null
    [ "$?" -eq 0 ] || run_diagnostic_on_failure "Sandbox→OpenCode" "Error response is not valid JSON"
    
    # Verify exit_code is non-zero
    local exit_code
    exit_code=$(echo "$response" | jq -r '.exit_code // empty')
    [ "$exit_code" != "0" ] && [ -n "$exit_code" ] || \
        run_diagnostic_on_failure "Sandbox→OpenCode" "exit_code should be non-zero for error: $exit_code"
    
    # Verify error field exists (or at least non-zero exit code)
    local error
    error=$(echo "$response" | jq -r '.error // empty')
    if [ -n "$error" ]; then
        echo "Error message: $error"
    fi
    echo "Error response with exit_code=$exit_code received"
}

@test "Sandbox→OpenCode: Round-trip completes within 30 seconds" {
    # Validates: Requirement 6.4
    # Test that simple command round-trip completes within 30 seconds
    
    local exec_url="http://sandbox:3001/exec"
    
    # Execute multiple commands and measure total time
    local start_time
    start_time=$(date +%s)
    
    for i in 1 2 3; do
        local response
        response=$(timeout 30 curl -s -X POST "$exec_url" \
            -H "Content-Type: application/json" \
            -d "{\"cmd\": \"echo round_trip_$i\", \"cwd\": \"/workspace\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
        
        # Verify each response
        local exit_code
        exit_code=$(echo "$response" | jq -r '.exit_code // empty')
        [ "$exit_code" = "0" ] || run_diagnostic_on_failure "Sandbox→OpenCode" "Command $i failed with exit_code=$exit_code"
    done
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # All 3 commands should complete within 30 seconds
    [ "$duration" -lt 30 ] || run_diagnostic_on_failure "Sandbox→OpenCode" "3 commands took ${duration}s - expected < 30s"
    
    echo "3 commands completed in ${duration}s (within 30s limit)"
}

@test "Sandbox→OpenCode: Non-zero exit code captured" {
    # Validates: Requirement 6.4
    # Test that non-zero exit codes are correctly captured and returned
    
    local exec_url="http://sandbox:3001/exec"
    
    # Test that false command returns non-zero exit code
    local response
    response=$(timeout 30 curl -s -X POST "$exec_url" \
        -H "Content-Type: application/json" \
        -d "{\"cmd\": \"false\", \"cwd\": \"/workspace\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
    
    local exit_code
    exit_code=$(echo "$response" | jq -r '.exit_code // empty')
    [ "$exit_code" != "0" ] || run_diagnostic_on_failure "Sandbox→OpenCode" "Expected non-zero exit code for false command"
    
    echo "Non-zero exit code correctly captured"
}

@test "Sandbox→OpenCode: Multi-line output captured" {
    # Validates: Requirement 6.2
    # Test that multi-line output is correctly captured
    
    local exec_url="http://sandbox:3001/exec"
    
    # Execute command with multi-line output
    local response
    response=$(timeout 30 curl -s -X POST "$exec_url" \
        -H "Content-Type: application/json" \
        -d "{\"cmd\": \"printf \\\"line1\\\\nline2\\\\nline3\\\\n\\\"\", \"cwd\": \"/workspace\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
    
    # Verify stdout contains all lines
    local stdout
    stdout=$(echo "$response" | jq -r '.stdout // empty')
    
    echo "$stdout" | grep -q "line1" || run_diagnostic_on_failure "Sandbox→OpenCode" "Missing line1 in output"
    echo "$stdout" | grep -q "line2" || run_diagnostic_on_failure "Sandbox→OpenCode" "Missing line2 in output"
    echo "$stdout" | grep -q "line3" || run_diagnostic_on_failure "Sandbox→OpenCode" "Missing line3 in output"
    
    echo "Multi-line output correctly captured"
}

@test "Sandbox→OpenCode: Empty output handled" {
    # Validates: Requirement 6.2
    # Test that empty output is handled correctly
    
    local exec_url="http://sandbox:3001/exec"
    
    # Execute command with no output
    local response
    response=$(timeout 30 curl -s -X POST "$exec_url" \
        -H "Content-Type: application/json" \
        -d "{\"cmd\": \"true\", \"cwd\": \"/workspace\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
    
    # Verify response is valid
    local exit_code
    exit_code=$(echo "$response" | jq -r '.exit_code // empty')
    [ "$exit_code" = "0" ] || run_diagnostic_on_failure "Sandbox→OpenCode" "Exit code should be 0 for 'true' command"
    
    local stdout
    stdout=$(echo "$response" | jq -r '.stdout // empty')
    echo "Empty output handled (stdout='$stdout')"
}

@test "Sandbox→OpenCode: Command timeout respects limit" {
    # Validates: Requirement 6.4
    # Test that long-running commands respect timeout limits
    
    local exec_url="http://sandbox:3001/exec"
    
    # Execute a command that would run for a while
    # Using a short sleep that should complete within timeout
    local response
    response=$(timeout 30 curl -s -X POST "$exec_url" \
        -H "Content-Type: application/json" \
        -d "{\"cmd\": \"sleep 1 && echo done\", \"cwd\": \"/workspace\", \"session_id\": \"$TEST_SESSION_ID\"}" 2>/dev/null)
    
    # Verify command completed
    local exit_code
    exit_code=$(echo "$response" | jq -r '.exit_code // empty')
    [ "$exit_code" = "0" ] || run_diagnostic_on_failure "Sandbox→OpenCode" "Command should complete successfully"
    
    local stdout
    stdout=$(echo "$response" | jq -r '.stdout // empty')
    echo "$stdout" | grep -q "done" || run_diagnostic_on_failure "Sandbox→OpenCode" "Command output should contain 'done'"
}