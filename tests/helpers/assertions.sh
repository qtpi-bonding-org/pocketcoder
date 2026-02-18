#!/usr/bin/env bash
# Custom assertions for BATS tests
# Provides common assertion helpers for test validation

# Assert that a value is not empty
assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"
    if [ -z "$value" ]; then
        echo "❌ $message" >&2
        return 1
    fi
}

# Assert that two values are equal
assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    if [ "$expected" != "$actual" ]; then
        echo "❌ $message" >&2
        echo "  Expected: $expected" >&2
        echo "  Actual:   $actual" >&2
        return 1
    fi
}

# Assert that a command returns success
assert_success() {
    local cmd="$1"
    local message="${2:-Command should succeed}"
    if ! eval "$cmd" > /dev/null 2>&1; then
        echo "❌ $message" >&2
        return 1
    fi
}

# Assert that a command returns failure
assert_failure() {
    local cmd="$1"
    local message="${2:-Command should fail}"
    if eval "$cmd" > /dev/null 2>&1; then
        echo "❌ $message" >&2
        return 1
    fi
}

# Assert that HTTP status code matches
assert_http_status() {
    local url="$1"
    local expected="$2"
    local actual
    actual=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    assert_equal "$expected" "$actual" "HTTP status should be $expected, got $actual"
}

# Assert that JSON response contains a field
assert_json_has_field() {
    local json="$1"
    local field="$2"
    local value
    value=$(echo "$json" | jq -r ".$field // empty" 2>/dev/null)
    assert_not_empty "$value" "JSON should have field: $field"
}

# Assert that JSON response matches a pattern
assert_json_equals() {
    local json="$1"
    local field="$2"
    local expected="$3"
    local actual
    actual=$(echo "$json" | jq -r ".$field // empty" 2>/dev/null)
    assert_equal "$expected" "$actual" "JSON field $field should equal $expected"
}

# Assert that a file exists
assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"
    if [ ! -f "$file" ]; then
        echo "❌ $message" >&2
        return 1
    fi
}

# Assert that a directory exists
assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist: $dir}"
    if [ ! -d "$dir" ]; then
        echo "❌ $message" >&2
        return 1
    fi
}

# Assert that a port is open
assert_port_open() {
    local port="$1"
    if ! nc -z localhost "$port" 2>/dev/null; then
        echo "❌ Port $port should be open" >&2
        return 1
    fi
}

# Assert that a port is closed
assert_port_closed() {
    local port="$1"
    if nc -z localhost "$port" 2>/dev/null; then
        echo "❌ Port $port should be closed" >&2
        return 1
    fi
}

# Assert that a string contains a substring
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"
    if [[ ! "$haystack" == *"$needle"* ]]; then
        echo "❌ $message" >&2
        echo "  Haystack: $haystack" >&2
        echo "  Needle:   $needle" >&2
        return 1
    fi
}

# Assert that a string does not contain a substring
assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not contain substring}"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "❌ $message" >&2
        echo "  Haystack: $haystack" >&2
        echo "  Needle:   $needle" >&2
        return 1
    fi
}

# Assert that a number is greater than a value
assert_gt() {
    local actual="$1"
    local threshold="$2"
    local message="${3:-Value should be greater than $threshold}"
    if [ "$actual" -le "$threshold" ]; then
        echo "❌ $message (actual: $actual)" >&2
        return 1
    fi
}

# Assert that a number is less than a value
assert_lt() {
    local actual="$1"
    local threshold="$2"
    local message="${3:-Value should be less than $threshold}"
    if [ "$actual" -ge "$threshold" ]; then
        echo "❌ $message (actual: $actual)" >&2
        return 1
    fi
}

# Assert that a number is within a range
assert_between() {
    local actual="$1"
    local min="$2"
    local max="$3"
    local message="${4:-Value should be between $min and $max}"
    if [ "$actual" -lt "$min" ] || [ "$actual" -gt "$max" ]; then
        echo "❌ $message (actual: $actual)" >&2
        return 1
    fi
}

# Assert that a response time is within threshold
assert_response_time() {
    local url="$1"
    local max_ms="$2"
    local start end duration
    start=$(date +%s%N)
    curl -s -o /dev/null "$url" > /dev/null 2>&1
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))

    assert_lt "$duration" "$max_ms" "Response time should be less than ${max_ms}ms (actual: ${duration}ms)"
}

# Assert that a container is healthy
assert_container_healthy() {
    local container="$1"
    local status
    status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
    assert_equal "healthy" "$status" "Container $container should be healthy"
}

# Assert that a tmux session exists
assert_tmux_session_exists() {
    local session="$1"
    local socket="${2:-/tmp/tmux/pocketcoder}"
    if ! tmux -S "$socket" has-session -t "$session" 2>/dev/null; then
        echo "❌ Tmux session should exist: $session" >&2
        return 1
    fi
}

# Assert that a process is running
assert_process_running() {
    local process="$1"
    if ! pgrep -f "$process" > /dev/null 2>&1; then
        echo "❌ Process should be running: $process" >&2
        return 1
    fi
}

# Assert that a command output matches a regex
assert_output_matches() {
    local expected_regex="$1"
    local message="${2:-Output should match regex}"
    if [[ ! "${output:-}" =~ $expected_regex ]]; then
        echo "❌ $message" >&2
        echo "  Output: ${output:-<empty>}" >&2
        echo "  Regex:  $expected_regex" >&2
        return 1
    fi
}