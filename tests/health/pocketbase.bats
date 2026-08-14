#!/usr/bin/env bats
# Current PocketBase health and basic database-access checks.

load '../helpers/auth.sh'
load '../helpers/cleanup.sh'
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

@test "PocketBase health endpoint returns 200 OK" {
    run curl -s -w "%{http_code}" "$PB_URL/api/health"
    [ "$status" -eq 0 ]
    [[ "${lines[-1]}" == "200" ]] || run_diagnostic_on_failure "PocketBase" "Health endpoint returned ${lines[-1]} instead of 200"
}

@test "PocketBase health check completes within 30 seconds" {
    run timeout 30 curl -s "$PB_URL/api/health"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PocketBase" "Health check timed out after 30 seconds"
}

@test "PocketBase accepts user authentication" {
    authenticate_user
    [ -n "$USER_TOKEN" ]
}

@test "PocketBase can create and query test records" {
    authenticate_user

    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Health Test Chat $TEST_ID\", \"user\": \"$USER_ID\"}")
    local chat_id
    chat_id=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$chat_id"

    local retrieved
    retrieved=$(pb_get "chats" "$chat_id")
    local title
    title=$(echo "$retrieved" | jq -r '.title')
    [ "$title" = "Health Test Chat $TEST_ID" ] || run_diagnostic_on_failure "PocketBase" "Failed to create or retrieve test chat record"
}

@test "PocketBase health check provides diagnostic information on failure" {
    run curl -s "$PB_URL/api/health"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "PocketBase" "Failed to get health endpoint response"

    echo "$output" | jq -e . >/dev/null
    [ "$?" -eq 0 ] || run_diagnostic_on_failure "PocketBase" "Health response is not valid JSON"
}
