#!/usr/bin/env bats
# Feature: Interface Health Check
#
# Lightweight connection tests for the Interface service /healthz endpoint.
# No LLM required — read-only, no teardown needed.

load '../helpers/auth.sh'
load '../helpers/assertions.sh'
load '../helpers/diagnostics.sh'

setup() {
    load_env
    INTERFACE_URL="${INTERFACE_URL:-http://interface:8080}"
}

@test "Interface health: GET /healthz returns HTTP 200 with valid JSON" {
    local http_code body
    http_code=$(curl -s -o /dev/null -w '%{http_code}' "${INTERFACE_URL}/healthz")
    [ "$http_code" = "200" ] || run_diagnostic_on_failure "Interface health" "Expected HTTP 200, got $http_code"

    body=$(curl -s "${INTERFACE_URL}/healthz")
    echo "$body" | jq . >/dev/null 2>&1 || run_diagnostic_on_failure "Interface health" "Response is not valid JSON: $body"
}

@test "Interface health: response contains expected status fields" {
    local body
    body=$(curl -s "${INTERFACE_URL}/healthz")

    assert_json_has_field "$body" "status"
    assert_json_has_field "$body" "eventPump"
    assert_json_has_field "$body" "commandPump"
    assert_json_has_field "$body" "sessionCacheSize"
}

@test "Interface health: status is 'ok' and pumps are 'connected'" {
    local body status event_pump command_pump session_cache_size
    body=$(curl -s "${INTERFACE_URL}/healthz")

    status=$(echo "$body" | jq -r '.status')
    assert_equal "$status" "ok"

    event_pump=$(echo "$body" | jq -r '.eventPump')
    assert_equal "$event_pump" "connected"

    command_pump=$(echo "$body" | jq -r '.commandPump')
    assert_equal "$command_pump" "connected"

    session_cache_size=$(echo "$body" | jq -r '.sessionCacheSize')
    [ "$session_cache_size" -ge 0 ] || run_diagnostic_on_failure "Interface health" "sessionCacheSize is not a non-negative number: $session_cache_size"
}
