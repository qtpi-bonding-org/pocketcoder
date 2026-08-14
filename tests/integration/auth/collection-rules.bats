#!/usr/bin/env bats
# Collection auth rules that remain part of the current PocketBase schema.

load '../../helpers/auth.sh'
load '../../helpers/cleanup.sh'

setup() {
    load_env
    TEST_ID=$(generate_test_id)
    export CURRENT_TEST_ID="$TEST_ID"
}

teardown() {
    cleanup_test_data "$TEST_ID" || true
}

@test "Auth Rules: unauthenticated list on chats returns empty results" {
    local response
    response=$(curl -s "$PB_URL/api/collections/chats/records")

    # PocketBase returns 200 with empty items for list rules that require auth.
    local total_items
    total_items=$(echo "$response" | jq -r '.totalItems // 0')
    [ "$total_items" -eq 0 ]
}
