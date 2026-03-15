#!/usr/bin/env bats
# Feature: test-suite-reorganization
# File Serving Integration Tests
# Validates: Requirements 10.7
#
# Tests the secure serving of feature files to the reasoning engine

load '../../helpers/auth.sh'
load '../../helpers/cleanup.sh'
load '../../helpers/wait.sh'
load '../../helpers/assertions.sh'
load '../../helpers/diagnostics.sh'
load '../../helpers/tracking.sh'

setup() {
    load_env
    TEST_ID=$(generate_test_id)
    export CURRENT_TEST_ID="$TEST_ID"
    TEST_FILE="file_test_$TEST_ID.txt"
    TEST_CONTENT="File content for feature test - $TEST_ID"
}

teardown() {
    # Clean up test files
    docker exec pocketcoder-sandbox rm -f "/workspace/$TEST_FILE" 2>/dev/null || true
}

@test "Files: Authenticate as superuser" {
    # Authenticate as superuser
    local auth_response
    auth_response=$(curl -s -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"$POCKETBASE_SUPERUSER_EMAIL\",\"password\":\"$POCKETBASE_SUPERUSER_PASSWORD\"}")

    local superuser_token
    superuser_token=$(echo "$auth_response" | jq -r '.token // empty')
    [ -n "$superuser_token" ] && [ "$superuser_token" != "null" ] || run_diagnostic_on_failure "Files" "Failed to authenticate as superuser"

    echo "✓ Superuser authenticated"
}

@test "Files: Create test file in workspace" {
    # Create test file
    docker exec pocketcoder-sandbox sh -c "echo '$TEST_CONTENT' > /workspace/$TEST_FILE"

    # Verify file exists
    run docker exec pocketcoder-sandbox test -f "/workspace/$TEST_FILE"
    [ "$status" -eq 0 ] || run_diagnostic_on_failure "Files" "Failed to create test file"

    echo "✓ Test file created in workspace"
}

@test "Files: Fetch file via API" {
    # Create test file
    docker exec pocketcoder-sandbox sh -c "echo '$TEST_CONTENT' > /workspace/$TEST_FILE"

    # Authenticate as superuser
    local auth_response
    auth_response=$(curl -s -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"$POCKETBASE_SUPERUSER_EMAIL\",\"password\":\"$POCKETBASE_SUPERUSER_PASSWORD\"}")

    local superuser_token
    superuser_token=$(echo "$auth_response" | jq -r '.token')

    # Fetch file
    local response
    response=$(curl -s -H "Authorization: $superuser_token" "$PB_URL/api/pocketcoder/files/$TEST_FILE")

    [ "$response" = "$TEST_CONTENT" ] || run_diagnostic_on_failure "Files" "File content mismatch. Expected: $TEST_CONTENT, Got: $response"

    echo "✓ File fetched successfully"
}

@test "Files: Verify file endpoint requires authentication" {
    # Create test file
    docker exec pocketcoder-sandbox sh -c "echo '$TEST_CONTENT' > /workspace/$TEST_FILE"

    # Try to fetch without authentication
    local response
    response=$(curl -s -w "%{http_code}" -o /dev/null "$PB_URL/api/pocketcoder/files/$TEST_FILE")

    # Should return 401 or 403 (unauthorized/forbidden)
    [ "$response" = "401" ] || [ "$response" = "403" ] || run_diagnostic_on_failure "Files" "Endpoint should require authentication, got HTTP $response"

    echo "✓ File endpoint requires authentication"
}

@test "Files: Fetch file with user token" {
    # Create test file
    docker exec pocketcoder-sandbox sh -c "echo '$TEST_CONTENT' > /workspace/$TEST_FILE"

    # Authenticate as regular user
    authenticate_user

    # Fetch file
    local response
    response=$(curl -s -H "Authorization: $USER_TOKEN" "$PB_URL/api/pocketcoder/files/$TEST_FILE")

    [ "$response" = "$TEST_CONTENT" ] || run_diagnostic_on_failure "Files" "File content mismatch with user token"

    echo "✓ File fetched with user token"
}

@test "Files: Handle non-existent file" {
    # Authenticate as superuser
    local auth_response
    auth_response=$(curl -s -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"$POCKETBASE_SUPERUSER_EMAIL\",\"password\":\"$POCKETBASE_SUPERUSER_PASSWORD\"}")

    local superuser_token
    superuser_token=$(echo "$auth_response" | jq -r '.token')

    # Try to fetch non-existent file
    local response
    response=$(curl -s -w "%{http_code}" -o /dev/null -H "Authorization: $superuser_token" "$PB_URL/api/pocketcoder/files/nonexistent_file_$TEST_ID.txt")

    # Should return 404 (not found)
    [ "$response" = "404" ] || run_diagnostic_on_failure "Files" "Non-existent file should return 404, got HTTP $response"

    echo "✓ Non-existent file returns 404"
}

@test "Files: Fetch file with special characters in filename" {
    # Create test file with special characters
    local special_file="file_test_$TEST_ID-special_file.txt"
    docker exec pocketcoder-sandbox sh -c "echo '$TEST_CONTENT' > /workspace/$special_file"

    # Authenticate as superuser
    local auth_response
    auth_response=$(curl -s -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"$POCKETBASE_SUPERUSER_EMAIL\",\"password\":\"$POCKETBASE_SUPERUSER_PASSWORD\"}")

    local superuser_token
    superuser_token=$(echo "$auth_response" | jq -r '.token')

    # Fetch file
    local response
    response=$(curl -s -H "Authorization: $superuser_token" "$PB_URL/api/pocketcoder/files/$special_file")

    [ "$response" = "$TEST_CONTENT" ] || run_diagnostic_on_failure "Files" "Failed to fetch file with special characters"

    # Cleanup
    docker exec pocketcoder-sandbox rm -f "/workspace/$special_file" 2>/dev/null || true

    echo "✓ File with special characters fetched successfully"
}

@test "Files: Fetch file from subdirectory" {
    # Create subdirectory and test file
    docker exec pocketcoder-sandbox sh -c "mkdir -p /workspace/test_subdir && echo '$TEST_CONTENT' > /workspace/test_subdir/$TEST_FILE"

    # Authenticate as superuser
    local auth_response
    auth_response=$(curl -s -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"$POCKETBASE_SUPERUSER_EMAIL\",\"password\":\"$POCKETBASE_SUPERUSER_PASSWORD\"}")

    local superuser_token
    superuser_token=$(echo "$auth_response" | jq -r '.token')

    # Fetch file from subdirectory
    local response
    response=$(curl -s -H "Authorization: $superuser_token" "$PB_URL/api/pocketcoder/files/test_subdir/$TEST_FILE")

    [ "$response" = "$TEST_CONTENT" ] || run_diagnostic_on_failure "Files" "Failed to fetch file from subdirectory"

    # Cleanup
    docker exec pocketcoder-sandbox rm -rf /workspace/test_subdir 2>/dev/null || true

    echo "✓ File from subdirectory fetched successfully"
}
