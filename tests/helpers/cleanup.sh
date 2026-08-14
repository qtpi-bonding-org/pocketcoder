#!/usr/bin/env bash
# Cleanup helpers for the current PocketBase-backed Bats tests.

PB_URL="${PB_URL:-${POCKETBASE_URL:-http://127.0.0.1:8090}}"

load_credentials() {
    if [ -f .env ]; then
        export $(grep -v '^#' .env | xargs)
    elif [ -f ../.env ]; then
        export $(grep -v '^#' ../.env | xargs)
    fi
}

get_admin_token() {
    if [ -n "${USER_TOKEN:-}" ]; then
        echo "$USER_TOKEN"
        return 0
    fi

    load_credentials
    local token_res
    token_res=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\": \"$POCKETBASE_ADMIN_EMAIL\", \"password\": \"$POCKETBASE_ADMIN_PASSWORD\"}")
    echo "$token_res" | jq -r '.token // empty'
}

delete_record() {
    local collection="$1"
    local record_id="$2"
    local token="${3:-$(get_admin_token)}"
    local http_code

    http_code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        "$PB_URL/api/collections/$collection/records/$record_id" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json")

    if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
        return 0
    fi

    echo "Failed to delete $collection/$record_id (HTTP $http_code)" >&2
    return 1
}

cleanup_test_data() {
    local test_id="$1"
    local token="${2:-$(get_admin_token)}"
    local response

    response=$(curl -s -G "$PB_URL/api/collections/chats/records" \
        --data-urlencode "filter=title~'$test_id'" \
        --data-urlencode "perPage=500" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json")

    local failed=0
    while IFS= read -r chat_id; do
        [ -n "$chat_id" ] || continue
        delete_record "chats" "$chat_id" "$token" || failed=1
    done < <(echo "$response" | jq -r '.items[]?.id // empty')

    return "$failed"
}

export -f delete_record cleanup_test_data load_credentials get_admin_token
