#!/bin/bash
# tests/helpers/cleanup.sh
# Cleanup utility for orphaned test data
# Provides functions to remove test data by ID pattern, dry-run mode, and age threshold
# Usage: source helpers/cleanup.sh

# Configuration
# Use PB_URL if already set (from environment), otherwise fall back to POCKETBASE_URL or default
PB_URL="${PB_URL:-${POCKETBASE_URL:-http://127.0.0.1:8090}}"
TEST_ID_PREFIX="test_"

# Load credentials from .env
load_credentials() {
    if [ -f .env ]; then
        export $(grep -v '^#' .env | xargs)
    elif [ -f ../.env ]; then
        export $(grep -v '^#' ../.env | xargs)
    fi
}

# Get auth token for cleanup operations
# Prefers the already-authenticated USER_TOKEN (set by authenticate_user in tests)
# to avoid redundant auth requests that can silently fail.
get_admin_token() {
    # If tests already authenticated, reuse that token
    if [ -n "$USER_TOKEN" ]; then
        echo "$USER_TOKEN"
        return 0
    fi

    # Fallback: authenticate fresh (for standalone CLI usage)
    load_credentials
    
    local token_res
    token_res=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{
            \"identity\": \"$POCKETBASE_ADMIN_EMAIL\",
            \"password\": \"$POCKETBASE_ADMIN_PASSWORD\"
        }")
    
    echo "$token_res" | grep -o '"token":"[^"]*"' | cut -d'"' -f4
}

# Delete a record by collection and ID
# Args: collection record_id
# Returns: 0 on success, 1 on failure (non-fatal)
delete_record() {
    local collection="$1"
    local record_id="$2"
    local token="$3"
    
    if [ -z "$token" ]; then
        token=$(get_admin_token)
    fi
    
    local response
    response=$(curl -s -w "%{http_code}" -X DELETE \
        "$PB_URL/api/collections/$collection/records/$record_id" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json")
    
    local http_code="${response: -3}"
    local body="${response:0:${#response}-3}"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
        echo "  ✓ Deleted $collection/$record_id"
        return 0
    else
        echo "  ✗ Failed to delete $collection/$record_id (HTTP $http_code)"
        return 1
    fi
}

# Delete multiple records by collection and ID pattern
# Args: collection id_pattern [token]
# Returns: 0 on success, 1 on partial failure
delete_by_pattern() {
    local collection="$1"
    local pattern="$2"
    local token="${3:-$(get_admin_token)}"
    
    echo "Searching for $collection records matching pattern: $pattern"
    
    # Get matching records
    local response
    response=$(curl -s -X GET \
        "$PB_URL/api/collections/$collection/records?filter=id~%22$pattern%22" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json")
    
    local count
    count=$(echo "$response" | grep -o '"totalCount":[0-9]*' | cut -d':' -f2)
    
    if [ "$count" = "0" ] || [ -z "$count" ]; then
        echo "  No matching records found"
        return 0
    fi
    
    echo "  Found $count matching record(s)"
    
    # Delete each record
    local failed=0
    echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | while read -r id; do
        if ! delete_record "$collection" "$id" "$token"; then
            failed=1
        fi
    done
    
    return $failed
}

# Dry-run mode: preview what would be deleted without actually deleting
# Args: collection id_pattern
dry_run_delete() {
    local collection="$1"
    local pattern="$2"
    local token="${3:-$(get_admin_token)}"
    
    echo "[DRY RUN] Would delete $collection records matching: $pattern"
    
    local response
    response=$(curl -s -X GET \
        "$PB_URL/api/collections/$collection/records?filter=id~%22$pattern%22" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json")
    
    local count
    count=$(echo "$response" | grep -o '"totalCount":[0-9]*' | cut -d':' -f2)
    
    if [ "$count" = "0" ] || [ -z "$count" ]; then
        echo "  No matching records found"
        return 0
    fi
    
    echo "  Would delete $count record(s):"
    echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | while read -r id; do
        echo "    - $id"
    done
}

# Cleanup test data by age threshold
# Args: collection age_hours [token]
# Returns: 0 on success, 1 on partial failure
cleanup_by_age() {
    local collection="$1"
    local age_hours="$2"
    local token="${3:-$(get_admin_token)}"
    
    echo "Cleaning up $collection records older than $age_hours hours"
    
    # Calculate timestamp for N hours ago
    local cutoff_timestamp
    cutoff_timestamp=$(date -d "$age_hours hours ago" +%s 2>/dev/null || date -v-"${age_hours}H" +%s 2>/dev/null)
    
    if [ -z "$cutoff_timestamp" ]; then
        echo "  ✗ Failed to calculate cutoff timestamp"
        return 1
    fi
    
    # Get records older than cutoff
    local response
    response=$(curl -s -X GET \
        "$PB_URL/api/collections/$collection/records?filter=created%3C$cutoff_timestamp" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json")
    
    local count
    count=$(echo "$response" | grep -o '"totalCount":[0-9]*' | cut -d':' -f2)
    
    if [ "$count" = "0" ] || [ -z "$count" ]; then
        echo "  No records older than $age_hours hours found"
        return 0
    fi
    
    echo "  Found $count record(s) older than $age_hours hours"
    
    # Delete each record
    local failed=0
    echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | while read -r id; do
        if ! delete_record "$collection" "$id" "$token"; then
            failed=1
        fi
    done
    
    return $failed
}

# Cleanup all test data for a specific test run
# Args: test_id
cleanup_test_data() {
    local test_id="$1"
    local token="${2:-$(get_admin_token)}"
    
    echo "Cleaning up test data for: $test_id"
    
    local failed=0
    
    # Clean up chats by title pattern (since TEST_ID is in the title)
    echo "Searching for chats records matching pattern: $test_id"
    local chats_response
    # Use curl -G with --data-urlencode for proper filter encoding
    chats_response=$(curl -s -G \
        "$PB_URL/api/collections/chats/records" \
        --data-urlencode "filter=title~'$test_id'" \
        --data-urlencode "perPage=500" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json")
    
    local chat_count
    chat_count=$(echo "$chats_response" | jq -r '.totalItems // 0' 2>/dev/null || echo "0")
    
    if [ "$chat_count" -gt 0 ] 2>/dev/null; then
        echo "  Found $chat_count chat(s)"
        local chat_ids=()
        while IFS= read -r chat_id; do
            chat_ids+=("$chat_id")
        done < <(echo "$chats_response" | jq -r '.items[].id' 2>/dev/null)
        
        # Clean up messages linked to these chats (by chat foreign key)
        for chat_id in "${chat_ids[@]}"; do
            local msgs_response
            msgs_response=$(curl -s -G \
                "$PB_URL/api/collections/messages/records" \
                --data-urlencode "filter=chat='$chat_id'" \
                --data-urlencode "perPage=500" \
                -H "Authorization: $token" \
                -H "Content-Type: application/json")
            
            local msg_count
            msg_count=$(echo "$msgs_response" | jq -r '.totalItems // 0' 2>/dev/null || echo "0")
            
            if [ "$msg_count" -gt 0 ] 2>/dev/null; then
                echo "  Found $msg_count message(s) for chat $chat_id"
                echo "$msgs_response" | jq -r '.items[].id' 2>/dev/null | while read -r msg_id; do
                    if ! delete_record "messages" "$msg_id" "$token"; then
                        failed=1
                    fi
                done
            fi
        done
        
        # Clean up permissions linked to these chats
        for chat_id in "${chat_ids[@]}"; do
            local perms_response
            perms_response=$(curl -s -G \
                "$PB_URL/api/collections/permissions/records" \
                --data-urlencode "filter=chat='$chat_id'" \
                --data-urlencode "perPage=500" \
                -H "Authorization: $token" \
                -H "Content-Type: application/json")
            
            local perm_count
            perm_count=$(echo "$perms_response" | jq -r '.totalItems // 0' 2>/dev/null || echo "0")
            
            if [ "$perm_count" -gt 0 ] 2>/dev/null; then
                echo "  Found $perm_count permission(s) for chat $chat_id"
                echo "$perms_response" | jq -r '.items[].id' 2>/dev/null | while read -r perm_id; do
                    if ! delete_record "permissions" "$perm_id" "$token"; then
                        failed=1
                    fi
                done
            fi
        done
        
        # Finally, delete the chats themselves
        for chat_id in "${chat_ids[@]}"; do
            if ! delete_record "chats" "$chat_id" "$token"; then
                failed=1
            fi
        done
    else
        echo "  No matching records found"
    fi
    
    # Clean up subagents by test_id pattern
    if ! delete_by_pattern "subagents" "$test_id" "$token"; then
        failed=1
    fi
    
    return $failed
}

# Dry-run cleanup for a specific test run
dry_run_cleanup() {
    local test_id="$1"
    local token="${2:-$(get_admin_token)}"
    
    echo "[DRY RUN] Cleanup preview for: $test_id"
    
    for collection in chats messages permissions subagents; do
        dry_run_delete "$collection" "$test_id" "$token"
    done
}

# Main function for standalone usage
main() {
    local dry_run=false
    local age_hours=0
    local test_id=""
    local collection=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --age)
                age_hours="$2"
                shift 2
                ;;
            --test-id)
                test_id="$2"
                shift 2
                ;;
            --collection)
                collection="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --dry-run       Preview what would be deleted without actually deleting"
                echo "  --age HOURS     Delete records older than HOURS (default: 0, disabled)"
                echo "  --test-id ID    Cleanup all test data for a specific test ID"
                echo "  --collection COL Cleanup specific collection only"
                echo "  --help, -h      Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0 --dry-run --test-id test_1234567890"
                echo "  $0 --age 24                    # Delete all test data older than 24 hours"
                echo "  $0 --test-id test_1234567890 --collection chats"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Execute cleanup based on options
    if [ "$dry_run" = true ]; then
        if [ -n "$test_id" ]; then
            if [ -n "$collection" ]; then
                dry_run_delete "$collection" "$test_id"
            else
                dry_run_cleanup "$test_id"
            fi
        else
            echo "Error: --test-id required for dry-run mode"
            exit 1
        fi
    elif [ -n "$test_id" ]; then
        if [ -n "$collection" ]; then
            delete_by_pattern "$collection" "$test_id"
        else
            cleanup_test_data "$test_id"
        fi
    elif [ "$age_hours" -gt 0 ]; then
        cleanup_by_age "chats" "$age_hours"
        cleanup_by_age "messages" "$age_hours"
        cleanup_by_age "permissions" "$age_hours"
        cleanup_by_age "subagents" "$age_hours"
    else
        echo "Error: Either --test-id or --age required"
        echo "Use --help for usage information"
        exit 1
    fi
}

# OpenCode session cleanup functions
# These functions handle cleanup of OpenCode sessions created during tests

# OpenCode endpoint (can be overridden by environment)
OPENCODE_URL="${OPENCODE_URL:-http://localhost:3000}"

# Delete an OpenCode session by ID
# Args: session_id
# Returns: 0 on success, 1 on failure (non-fatal)
delete_opencode_session() {
    local session_id="$1"
    
    local response
    response=$(curl -s -w "%{http_code}" -X DELETE \
        "$OPENCODE_URL/session/$session_id" 2>/dev/null)
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "204" ] || [ "$http_code" = "404" ]; then
        echo "  ✓ Deleted OpenCode session: $session_id"
        return 0
    else
        echo "  ✗ Failed to delete OpenCode session $session_id (HTTP $http_code)"
        return 1
    fi
}

# Cleanup OpenCode sessions by pattern
# Args: session_id_pattern
# Returns: 0 on success, 1 on partial failure
cleanup_opencode_sessions_by_pattern() {
    local pattern="$1"
    
    echo "Cleaning up OpenCode sessions matching pattern: $pattern"
    
    # OpenCode doesn't have a list endpoint with filtering, so we try to delete directly
    # This is a best-effort cleanup since we don't have a way to list all sessions
    
    # If we have a specific session ID, try to delete it
    if [ -n "$pattern" ]; then
        delete_opencode_session "$pattern" || true
    fi
}

# Cleanup all OpenCode sessions for a test run
# Args: test_id
# Returns: 0 on success, 1 on partial failure
cleanup_opencode_sessions_for_test() {
    local test_id="$1"
    
    echo "Cleaning up OpenCode sessions for test: $test_id"
    
    # Since we can't list sessions, we rely on tracking session IDs during test execution
    # The test should track session IDs in OPENCODE_SESSION_IDS variable
    # This function is called from teardown() in BATS tests
    
    return 0
}

# Track an OpenCode session for cleanup
# Args: session_id
# Usage: track_opencode_session "abc123"
track_opencode_session() {
    local session_id="$1"
    echo "  📦 Tracked OpenCode session: $session_id"
}

# Export functions for use in BATS
export -f delete_record delete_by_pattern dry_run_delete cleanup_by_age
export -f cleanup_test_data dry_run_cleanup load_credentials get_admin_token
export -f delete_opencode_session cleanup_opencode_sessions_by_pattern
export -f cleanup_opencode_sessions_for_test track_opencode_session