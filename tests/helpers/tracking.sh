#!/bin/bash
# tests/helpers/tracking.sh
# Test data tracking utilities for BATS tests
# Provides unique ID generation, artifact tracking, and cleanup hooks
# Usage: source helpers/tracking.sh

# Global array to track created artifacts
declare -a TEST_ARTIFACTS=()

# Generate unique test ID
# Format: test_$(date +%s)_$(printf "%04d" $RANDOM)
# Returns: unique test ID string
generate_test_id() {
    local timestamp
    timestamp=$(date +%s)
    local random
    random=$(printf "%04d" $RANDOM)
    echo "test_${timestamp}_${random}"
}

# Add an artifact to the tracking list
# Args: collection:record_id
# Usage: track_artifact "chats:abc123"
track_artifact() {
    local artifact="$1"
    TEST_ARTIFACTS+=("$artifact")
    echo "  📦 Tracked artifact: $artifact"
}

# Track multiple artifacts at once
# Args: collection record_id [record_id ...]
# Usage: track_artifacts "chats" "abc123" "def456"
track_artifacts() {
    local collection="$1"
    shift
    local ids=("$@")
    for id in "${ids[@]}"; do
        track_artifact "$collection:$id"
    done
}

# Track a chat record
# Args: chat_id
track_chat() {
    local chat_id="$1"
    track_artifact "chats:$chat_id"
}

# Track a message record
# Args: message_id
track_message() {
    local message_id="$1"
    track_artifact "messages:$message_id"
}

# Track a permission record
# Args: permission_id
track_permission() {
    local permission_id="$1"
    track_artifact "permissions:$permission_id"
}

# Track a subagent record
# Args: subagent_id
track_subagent() {
    local subagent_id="$1"
    track_artifact "subagents:$subagent_id"
}

# Get all tracked artifacts
# Returns: space-separated list of artifacts
get_tracked_artifacts() {
    echo "${TEST_ARTIFACTS[@]}"
}

# Get count of tracked artifacts
get_artifact_count() {
    echo ${#TEST_ARTIFACTS[@]}
}

# Clear all tracked artifacts
clear_artifacts() {
    TEST_ARTIFACTS=()
}

# Cleanup all tracked artifacts
# Args: [token]
# Returns: 0 on success, 1 on partial failure
cleanup_tracked_artifacts() {
    local token="${1:-}"
    local failed=0
    
    if [ $(get_artifact_count) -eq 0 ]; then
        echo "  No artifacts to clean up"
        return 0
    fi
    
    echo "  Cleaning up $(get_artifact_count) artifact(s)..."
    
    for artifact in "${TEST_ARTIFACTS[@]}"; do
        local collection="${artifact%%:*}"
        local id="${artifact#*:}"
        
        if ! delete_artifact "$collection" "$id" "$token"; then
            failed=1
        fi
    done
    
    clear_artifacts
    return $failed
}

# Delete a single artifact
# Args: collection record_id [token]
delete_artifact() {
    local collection="$1"
    local id="$2"
    local token="$3"
    
    if [ -z "$token" ]; then
        token=$(get_admin_token)
    fi
    
    local response
    response=$(curl -s -w "%{http_code}" -X DELETE \
        "$PB_URL/api/collections/$collection/records/$id" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
        echo "    ✓ Cleaned up $collection/$id"
        return 0
    else
        echo "    ⚠ Could not clean up $collection/$id (HTTP $http_code)"
        return 1
    fi
}

# Get admin token for cleanup operations
get_admin_token() {
    load_env
    
    local token_res
    token_res=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{
            \"identity\": \"$POCKETBASE_ADMIN_EMAIL\",
            \"password\": \"$POCKETBASE_ADMIN_PASSWORD\"
        }")
    
    echo "$token_res" | grep -o '"token":"[^"]*"' | cut -d'"' -f4
}

# Load environment variables
load_env() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$script_dir/../test-env.sh" ]; then
        source "$script_dir/../test-env.sh"
    fi
    if [ -f .env ]; then
        set -a
        source .env
        set +a
    fi
}

# BATS teardown hook for automatic cleanup
# Usage: teardown() { cleanup_test_artifacts || true; }
cleanup_test_artifacts() {
    if [ $(get_artifact_count) -gt 0 ]; then
        echo "Cleaning up test artifacts..."
        cleanup_tracked_artifacts || true
    fi
}

# Create test data and track it
# Args: collection data_json
# Returns: created record ID
create_and_track() {
    local collection="$1"
    local data="$2"
    
    local response
    response=$(pb_create "$collection" "$data")
    
    local id
    id=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$id" ]; then
        track_artifact "$collection:$id"
        echo "$id"
    else
        echo "Failed to create record in $collection" >&2
        return 1
    fi
}

# Create a test chat and track it
# Args: title user_id
# Returns: chat record ID
create_test_chat() {
    local title="${1:-Test Chat}"
    local user_id="${2:-$USER_ID}"
    
    local data="{\"title\": \"$title\", \"user\": \"$user_id\"}"
    create_and_track "chats" "$data"
}

# Create a test message and track it
# Args: chat_id role parts
# Returns: message record ID
create_test_message() {
    local chat_id="$1"
    local role="${2:-user}"
    local parts="${3:-[{\"type\": \"text\", \"text\": \"test message\"}]}"
    
    local data="{\"chat\": \"$chat_id\", \"role\": \"$role\", \"parts\": $parts}"
    create_and_track "messages" "$data"
}

# Export functions for use in BATS
export -f generate_test_id track_artifact track_artifacts
export -f track_chat track_message track_permission track_subagent
export -f get_tracked_artifacts get_artifact_count clear_artifacts
export -f cleanup_tracked_artifacts delete_artifact
export -f cleanup_test_artifacts create_and_track
export -f create_test_chat create_test_message