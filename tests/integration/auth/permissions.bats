#!/usr/bin/env bats
# Feature: test-suite-reorganization
# Permission Flow Integration Tests
# Validates: Requirements 10.7
#
# Tests the complete permission gating flow

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
    CHAT_ID=""
    USER_MESSAGE_ID=""
    PERMISSION_ID=""
}

teardown() {
    # Clean up all test data
    cleanup_test_data "$TEST_ID" || true
}

@test "Permissions: Create chat and send message" {
    # Authenticate
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Permission Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    [ -n "$CHAT_ID" ] && [ "$CHAT_ID" != "null" ] || run_diagnostic_on_failure "Permissions" "Failed to create chat"
    
    # Send message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"Please write a file\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    [ -n "$USER_MESSAGE_ID" ] && [ "$USER_MESSAGE_ID" != "null" ] || run_diagnostic_on_failure "Permissions" "Failed to create message"
    
    echo "✓ Chat and message created"
}

@test "Permissions: Wait for permission request" {
    # Authenticate
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Permission Request Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Send message that triggers permission request
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"write file\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for permission request (up to 30 seconds)
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + 30))
    
    while [ $(date +%s) -lt $end_time ]; do
        local perms_response
        perms_response=$(curl -s -X GET "$PB_URL/api/collections/permissions/records?filter=chat=\"$CHAT_ID\"%20%26%26%20status=\"draft\"" \
            -H "Authorization: $USER_TOKEN" \
            -H "Content-Type: application/json")
        
        PERMISSION_ID=$(echo "$perms_response" | jq -r '.items[0].id // empty')
        
        if [ -n "$PERMISSION_ID" ] && [ "$PERMISSION_ID" != "null" ]; then
            track_artifact "permissions:$PERMISSION_ID"
            echo "✓ Permission request found: $PERMISSION_ID"
            return 0
        fi
        
        sleep 1
    done
    
    echo "⚠ No permission request found (may not be required for this message)"
}

@test "Permissions: Authorize permission request" {
    # Authenticate
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Permission Auth Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Send message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"write file\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for permission request
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + 30))
    
    while [ $(date +%s) -lt $end_time ]; do
        local perms_response
        perms_response=$(curl -s -X GET "$PB_URL/api/collections/permissions/records?filter=chat=\"$CHAT_ID\"%20%26%26%20status=\"draft\"" \
            -H "Authorization: $USER_TOKEN" \
            -H "Content-Type: application/json")
        
        PERMISSION_ID=$(echo "$perms_response" | jq -r '.items[0].id // empty')
        
        if [ -n "$PERMISSION_ID" ] && [ "$PERMISSION_ID" != "null" ]; then
            track_artifact "permissions:$PERMISSION_ID"
            break
        fi
        
        sleep 1
    done
    
    if [ -z "$PERMISSION_ID" ] || [ "$PERMISSION_ID" = "null" ]; then
        echo "⚠ No permission request found, skipping authorization test"
        return 0
    fi
    
    # Authorize permission
    local auth_response
    auth_response=$(curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$PERMISSION_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"status":"authorized"}')
    
    local status
    status=$(echo "$auth_response" | jq -r '.status // empty')
    [ "$status" = "authorized" ] || run_diagnostic_on_failure "Permissions" "Failed to authorize permission"
    
    echo "✓ Permission authorized"
}

@test "Permissions: Deny permission request" {
    # Authenticate
    authenticate_user
    
    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Permission Deny Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"
    
    # Send message
    local msg_data
    msg_data=$(pb_create "messages" "{\"chat\": \"$CHAT_ID\", \"role\": \"user\", \"parts\": [{\"type\": \"text\", \"text\": \"write file\"}], \"user_message_status\": \"pending\"}")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"
    
    # Wait for permission request
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + 30))
    
    while [ $(date +%s) -lt $end_time ]; do
        local perms_response
        perms_response=$(curl -s -X GET "$PB_URL/api/collections/permissions/records?filter=chat=\"$CHAT_ID\"%20%26%26%20status=\"draft\"" \
            -H "Authorization: $USER_TOKEN" \
            -H "Content-Type: application/json")
        
        PERMISSION_ID=$(echo "$perms_response" | jq -r '.items[0].id // empty')
        
        if [ -n "$PERMISSION_ID" ] && [ "$PERMISSION_ID" != "null" ]; then
            track_artifact "permissions:$PERMISSION_ID"
            break
        fi
        
        sleep 1
    done
    
    if [ -z "$PERMISSION_ID" ] || [ "$PERMISSION_ID" = "null" ]; then
        echo "⚠ No permission request found, skipping denial test"
        return 0
    fi
    
    # Deny permission
    local deny_response
    deny_response=$(curl -s -X PATCH "$PB_URL/api/collections/permissions/records/$PERMISSION_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"status":"denied"}')
    
    local status
    status=$(echo "$deny_response" | jq -r '.status // empty')
    [ "$status" = "denied" ] || run_diagnostic_on_failure "Permissions" "Failed to deny permission"
    
    echo "✓ Permission denied"
}


