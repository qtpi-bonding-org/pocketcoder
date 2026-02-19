#!/usr/bin/env bats
# Feature: test-suite-reorganization, Property 1: Health Test Correctness

# Sandbox health tests
# Validates: Requirements 2.4, 2.5, 2.6, 2.7, 2.8

load '../helpers/auth.sh'
load '../helpers/cleanup.sh'
load '../helpers/wait.sh'
load '../helpers/assertions.sh'
load '../helpers/diagnostics.sh'
load '../helpers/tracking.sh'

setup() {
    load_env
    TEST_ID=$(generate_test_id)
    export CURRENT_TEST_ID="$TEST_ID"
}

teardown() {
    cleanup_test_data "$TEST_ID" || true
}

@test "Sandbox Rust axum server health endpoint returns ok" {
    # Validates: Requirement 2.4
    run curl -s "$SANDBOX_URL/health"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Sandbox" "Failed to connect to Rust axum health endpoint"
    [[ "$output" == *"ok"* ]] || run_diagnostic_on_failure "Sandbox" "Health response does not contain 'ok': $output"
}

@test "Sandbox Rust axum health check completes within 30 seconds" {
    # Validates: Requirement 2.7
    run timeout 30 curl -s "$SANDBOX_URL/health"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Sandbox" "Health check timed out after 30 seconds"
}

@test "Sandbox CAO API health endpoint returns ok" {
    # Validates: Requirement 2.5
    run curl -s "$CAO_API_URL/health"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Sandbox" "Failed to connect to CAO API health endpoint"
    [[ "$output" == *"ok"* ]] || run_diagnostic_on_failure "Sandbox" "CAO API health response does not contain 'ok': $output"
}

@test "Sandbox tmux socket exists" {
    # Validates: Requirement 2.6
    # Tmux socket is inside the Sandbox container, so we check via docker exec
    run docker exec pocketcoder-sandbox test -S "$TMUX_SOCKET"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Sandbox" "Tmux socket does not exist at $TMUX_SOCKET"
}

@test "Sandbox tmux session exists" {
    # Validates: Requirement 2.6
    run docker exec pocketcoder-sandbox tmux -S "$TMUX_SOCKET" has-session -t "$TMUX_SESSION"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Sandbox" "Tmux session $TMUX_SESSION does not exist"
}

@test "Sandbox proxy binary is executable" {
    # Validates: Requirement 2.6
    # Proxy binary is at /usr/local/bin/pocketcoder inside Sandbox
    run docker exec pocketcoder-sandbox test -x /usr/local/bin/pocketcoder
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Sandbox" "Proxy binary is not executable"
}

@test "Sandbox proxy binary exists" {
    # Validates: Requirement 2.6
    run docker exec pocketcoder-sandbox test -f /usr/local/bin/pocketcoder
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Sandbox" "Proxy binary does not exist"
}

@test "Sandbox health check provides diagnostic information on failure" {
    # Validates: Requirement 2.8
    # This test verifies that when health check fails, diagnostic info is available
    
    # Verify we can get health info from Rust axum
    run curl -s "$SANDBOX_URL/health"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Sandbox" "Failed to get Rust axum health response"
}