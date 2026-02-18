#!/usr/bin/env bash
# Authentication helper for PocketBase API testing
# Usage: load '../helpers/auth.sh'
# This file reads credentials from .env and provides auth functions

# Container endpoint (can be overridden by environment)
PB_URL="${PB_URL:-http://localhost:8090}"

# Load .env file to get credentials
load_env() {
    local env_file="${1:-.env}"
    # Source test-env.sh for default URLs and config
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$script_dir/../test-env.sh" ]; then
        source "$script_dir/../test-env.sh"
    fi
    # Source .env for credentials
    if [ -f "$env_file" ]; then
        set -a
        source "$env_file"
        set +a
    fi
}

# Authenticate as regular user
# Sets USER_TOKEN and USER_ID
authenticate_user() {
    load_env

    local email="${POCKETBASE_ADMIN_EMAIL:-}"
    local password="${POCKETBASE_ADMIN_PASSWORD:-}"

    if [ -z "$email" ] || [ -z "$password" ]; then
        echo "❌ Error: POCKETBASE_ADMIN_EMAIL or POCKETBASE_ADMIN_PASSWORD not found" >&2
        return 1
    fi

    local token_res
    token_res=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\": \"$email\", \"password\": \"$password\"}")

    USER_TOKEN=$(echo "$token_res" | jq -r '.token // empty')
    USER_ID=$(echo "$token_res" | jq -r '.record.id // empty')

    if [ -z "$USER_TOKEN" ]; then
        echo "❌ Failed to authenticate as user" >&2
        echo "Response: $token_res" >&2
        return 1
    fi

    export USER_TOKEN USER_ID
    echo "✅ Authenticated as user: $USER_ID"
}

# Authenticate as superuser
# Sets USER_TOKEN and USER_ID
authenticate_superuser() {
    load_env

    local email="${POCKETBASE_SUPERUSER_EMAIL:-}"
    local password="${POCKETBASE_SUPERUSER_PASSWORD:-}"

    if [ -z "$email" ] || [ -z "$password" ]; then
        echo "❌ Error: POCKETBASE_SUPERUSER_EMAIL or POCKETBASE_SUPERUSER_PASSWORD not found" >&2
        return 1
    fi

    local token_res
    token_res=$(curl -s -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\": \"$email\", \"password\": \"$password\"}")

    USER_TOKEN=$(echo "$token_res" | jq -r '.token // empty')
    USER_ID=$(echo "$token_res" | jq -r '.record.id // empty')

    if [ -z "$USER_TOKEN" ]; then
        echo "❌ Failed to authenticate as superuser" >&2
        echo "Response: $token_res" >&2
        return 1
    fi

    export USER_TOKEN USER_ID
    echo "✅ Authenticated as superuser: $USER_ID"
}

# Make authenticated request to PocketBase
# Usage: pb_request "GET" "/api/collections/chats/records"
pb_request() {
    local method="$1"
    local path="$2"
    local data="${3:-}"

    if [ -z "$USER_TOKEN" ]; then
        echo "❌ Error: USER_TOKEN not set. Call authenticate_user first." >&2
        return 1
    fi

    local opts=("-X" "$method")
    if [ -n "$data" ]; then
        opts+=("-H" "Content-Type: application/json" "-d" "$data")
    fi

    curl -s "${opts[@]}" \
        -H "Authorization: $USER_TOKEN" \
        "$PB_URL$path"
}

# Create a record in a collection
# Usage: pb_create "chats" '{"title": "Test Chat", "user": "..."}'
pb_create() {
    local collection="$1"
    local data="$2"
    pb_request "POST" "/api/collections/$collection/records" "$data"
}

# Get a record from a collection
# Usage: pb_get "chats" "record_id"
pb_get() {
    local collection="$1"
    local id="$2"
    pb_request "GET" "/api/collections/$collection/records/$id"
}

# Update a record in a collection
# Usage: pb_update "chats" "record_id" '{"title": "Updated Title"}'
pb_update() {
    local collection="$1"
    local id="$2"
    local data="$3"
    pb_request "PATCH" "/api/collections/$collection/records/$id" "$data"
}

# Delete a record from a collection
# Usage: pb_delete "chats" "record_id"
pb_delete() {
    local collection="$1"
    local id="$2"
    pb_request "DELETE" "/api/collections/$collection/records/$id"
}

# List records in a collection
# Usage: pb_list "chats" "?filter=user='...'"
pb_list() {
    local collection="$1"
    local filter="${2:-}"
    pb_request "GET" "/api/collections/$collection/records$filter"
}