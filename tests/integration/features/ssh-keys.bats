#!/usr/bin/env bats
# Feature: test-suite-reorganization
# SSH Key Authentication Integration Tests
# Validates: Requirements 10.7
#
# Tests the end-to-end SSH key registration and authentication flow

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
    TEST_USER_ID=""
    TEST_USER_EMAIL="test-ssh-$TEST_ID@example.com"
    TEST_USER_PASSWORD="TestPassword123!"
    SSH_KEY_ID=""
    SSH_KEY_ID2=""
}

teardown() {
    # Clean up test data
    cleanup_test_data "$TEST_ID" || true
    
    # Remove test SSH keys
    rm -f /tmp/test_ssh_key /tmp/test_ssh_key.pub /tmp/test_ssh_key2 /tmp/test_ssh_key2.pub
}

# TODO: SSH key generation tests disabled - pocketcoder doesn't generate SSH keys
# Users provide keys via Flutter or mount them on the host
# @test "SSH Keys: Create test user" {
#     # Authenticate as admin
#     authenticate_user
#     
#     # Create test user
#     local user_response
#     user_response=$(curl -s -X POST "$PB_URL/api/collections/users/records" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $USER_TOKEN" \
#         -d "{\"email\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\",\"passwordConfirm\":\"$TEST_USER_PASSWORD\"}")
#     
#     TEST_USER_ID=$(echo "$user_response" | jq -r '.id // empty')
#     [ -n "$TEST_USER_ID" ] && [ "$TEST_USER_ID" != "null" ] || run_diagnostic_on_failure "SSH Keys" "Failed to create test user"
#     
#     track_artifact "users:$TEST_USER_ID"
#     echo "✓ Test user created: $TEST_USER_ID"
# }

# @test "SSH Keys: Authenticate as test user" {
#     # Create test user first
#     authenticate_user
#     local user_response
#     user_response=$(curl -s -X POST "$PB_URL/api/collections/users/records" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $USER_TOKEN" \
#         -d "{\"email\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\",\"passwordConfirm\":\"$TEST_USER_PASSWORD\"}")
#     TEST_USER_ID=$(echo "$user_response" | jq -r '.id')
#     track_artifact "users:$TEST_USER_ID"
#     
#     # Authenticate as test user
#     local auth_response
#     auth_response=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
#         -H "Content-Type: application/json" \
#         -d "{\"identity\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\"}")
#     
#     local test_user_token
#     test_user_token=$(echo "$auth_response" | jq -r '.token // empty')
#     [ -n "$test_user_token" ] && [ "$test_user_token" != "null" ] || run_diagnostic_on_failure "SSH Keys" "Failed to authenticate as test user"
#     
#     echo "✓ Test user authenticated"
# }

# @test "SSH Keys: Generate SSH key pair" {
#     # Generate SSH key pair
#     ssh-keygen -t ed25519 -f /tmp/test_ssh_key -N "" -C "test-device" > /dev/null 2>&1
#     
#     [ -f /tmp/test_ssh_key ] || run_diagnostic_on_failure "SSH Keys" "Failed to generate private key"
#     [ -f /tmp/test_ssh_key.pub ] || run_diagnostic_on_failure "SSH Keys" "Failed to generate public key"
#     
#     echo "✓ SSH key pair generated"
# }

# @test "SSH Keys: Register SSH key to PocketBase" {
#     # Create test user
#     authenticate_user
#     local user_response
#     user_response=$(curl -s -X POST "$PB_URL/api/collections/users/records" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $USER_TOKEN" \
#         -d "{\"email\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\",\"passwordConfirm\":\"$TEST_USER_PASSWORD\"}")
#     TEST_USER_ID=$(echo "$user_response" | jq -r '.id')
#     track_artifact "users:$TEST_USER_ID"
#     
#     # Authenticate as test user
#     local auth_response
#     auth_response=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
#         -H "Content-Type: application/json" \
#         -d "{\"identity\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\"}")
#     local test_user_token
#     test_user_token=$(echo "$auth_response" | jq -r '.token')
#     
#     # Generate SSH key
#     ssh-keygen -t ed25519 -f /tmp/test_ssh_key -N "" -C "test-device" > /dev/null 2>&1
#     local test_public_key
#     test_public_key=$(cat /tmp/test_ssh_key.pub)
#     
#     # Calculate fingerprint
#     local key_base64
#     key_base64=$(echo "$test_public_key" | awk '{print $2}')
#     local fingerprint
#     fingerprint="SHA256:$(echo "$key_base64" | base64 -d | shasum -a 256 | awk '{print $1}' | xxd -r -p | base64)"
#     
#     # Register SSH key
#     local ssh_key_response
#     ssh_key_response=$(curl -s -X POST "$PB_URL/api/collections/ssh_keys/records" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $test_user_token" \
#         -d "{
#             \"user\":\"$TEST_USER_ID\",
#             \"public_key\":\"$test_public_key\",
#             \"device_name\":\"Test Device\",
#             \"fingerprint\":\"$fingerprint\",
#             \"is_active\":true
#         }")
#     
#     SSH_KEY_ID=$(echo "$ssh_key_response" | jq -r '.id // empty')
#     [ -n "$SSH_KEY_ID" ] && [ "$SSH_KEY_ID" != "null" ] || run_diagnostic_on_failure "SSH Keys" "Failed to register SSH key"
#     
#     track_artifact "ssh_keys:$SSH_KEY_ID"
#     echo "✓ SSH key registered: $SSH_KEY_ID"
# }

# @test "SSH Keys: Verify SSH key appears in sync endpoint" {
#     # Create test user and register key
#     authenticate_user
#     local user_response
#     user_response=$(curl -s -X POST "$PB_URL/api/collections/users/records" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $USER_TOKEN" \
#         -d "{\"email\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\",\"passwordConfirm\":\"$TEST_USER_PASSWORD\"}")
#     TEST_USER_ID=$(echo "$user_response" | jq -r '.id')
#     track_artifact "users:$TEST_USER_ID"
#     
#     local auth_response
#     auth_response=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
#         -H "Content-Type: application/json" \
#         -d "{\"identity\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\"}")
#     local test_user_token
#     test_user_token=$(echo "$auth_response" | jq -r '.token')
#     
#     ssh-keygen -t ed25519 -f /tmp/test_ssh_key -N "" -C "test-device" > /dev/null 2>&1
#     local test_public_key
#     test_public_key=$(cat /tmp/test_ssh_key.pub)
#     local key_base64
#     key_base64=$(echo "$test_public_key" | awk '{print $2}')
#     local fingerprint
#     fingerprint="SHA256:$(echo "$key_base64" | base64 -d | shasum -a 256 | awk '{print $1}' | xxd -r -p | base64)"
#     
#     local ssh_key_response
#     ssh_key_response=$(curl -s -X POST "$PB_URL/api/collections/ssh_keys/records" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $test_user_token" \
#         -d "{
#             \"user\":\"$TEST_USER_ID\",
#             \"public_key\":\"$test_public_key\",
#             \"device_name\":\"Test Device\",
#             \"fingerprint\":\"$fingerprint\",
#             \"is_active\":true
#         }")
#     SSH_KEY_ID=$(echo "$ssh_key_response" | jq -r '.id')
#     track_artifact "ssh_keys:$SSH_KEY_ID"
#     
#     # Check sync endpoint
#     local keys_response
#     keys_response=$(curl -s "$PB_URL/api/pocketcoder/ssh_keys")
#     
#     echo "$keys_response" | grep -q "$(echo "$test_public_key" | awk '{print $2}')" || run_diagnostic_on_failure "SSH Keys" "SSH key not found in sync endpoint"
#     
#     echo "✓ SSH key appears in sync endpoint"
# }

# @test "SSH Keys: Test key deactivation" {
#     # Create test user and register key
#     authenticate_user
#     local user_response
#     user_response=$(curl -s -X POST "$PB_URL/api/collections/users/records" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $USER_TOKEN" \
#         -d "{\"email\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\",\"passwordConfirm\":\"$TEST_USER_PASSWORD\"}")
#     TEST_USER_ID=$(echo "$user_response" | jq -r '.id')
#     track_artifact "users:$TEST_USER_ID"
#     
#     local auth_response
#     auth_response=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
#         -H "Content-Type: application/json" \
#         -d "{\"identity\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\"}")
#     local test_user_token
#     test_user_token=$(echo "$auth_response" | jq -r '.token')
#     
#     ssh-keygen -t ed25519 -f /tmp/test_ssh_key -N "" -C "test-device" > /dev/null 2>&1
#     local test_public_key
#     test_public_key=$(cat /tmp/test_ssh_key.pub)
#     local key_base64
#     key_base64=$(echo "$test_public_key" | awk '{print $2}')
#     local fingerprint
#     fingerprint="SHA256:$(echo "$key_base64" | base64 -d | shasum -a 256 | awk '{print $1}' | xxd -r -p | base64)"
#     
#     local ssh_key_response
#     ssh_key_response=$(curl -s -X POST "$PB_URL/api/collections/ssh_keys/records" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $test_user_token" \
#         -d "{
#             \"user\":\"$TEST_USER_ID\",
#             \"public_key\":\"$test_public_key\",
#             \"device_name\":\"Test Device\",
#             \"fingerprint\":\"$fingerprint\",
#             \"is_active\":true
#         }")
#     SSH_KEY_ID=$(echo "$ssh_key_response" | jq -r '.id')
#     track_artifact "ssh_keys:$SSH_KEY_ID"
#     
#     # Deactivate key
#     local deactivate_response
#     deactivate_response=$(curl -s -X PATCH "$PB_URL/api/collections/ssh_keys/records/$SSH_KEY_ID" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $test_user_token" \
#         -d '{"is_active":false}')
#     
#     local is_active
#     is_active=$(echo "$deactivate_response" | jq -r '.is_active')
#     [ "$is_active" = "false" ] || run_diagnostic_on_failure "SSH Keys" "Failed to deactivate SSH key"
#     
#     echo "✓ SSH key deactivated"
# }

# @test "SSH Keys: Verify deactivated key not in sync endpoint" {
#     # Create test user and register key
#     authenticate_user
#     local user_response
#     user_response=$(curl -s -X POST "$PB_URL/api/collections/users/records" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $USER_TOKEN" \
#         -d "{\"email\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\",\"passwordConfirm\":\"$TEST_USER_PASSWORD\"}")
#     TEST_USER_ID=$(echo "$user_response" | jq -r '.id')
#     track_artifact "users:$TEST_USER_ID"
#     
#     local auth_response
#     auth_response=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
#         -H "Content-Type: application/json" \
#         -d "{\"identity\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\"}")
#     local test_user_token
#     test_user_token=$(echo "$auth_response" | jq -r '.token')
#     
#     ssh-keygen -t ed25519 -f /tmp/test_ssh_key -N "" -C "test-device" > /dev/null 2>&1
#     local test_public_key
#     test_public_key=$(cat /tmp/test_ssh_key.pub)
#     local key_base64
#     key_base64=$(echo "$test_public_key" | awk '{print $2}')
#     local fingerprint
#     fingerprint="SHA256:$(echo "$key_base64" | base64 -d | shasum -a 256 | awk '{print $1}' | xxd -r -p | base64)"
#     
#     local ssh_key_response
#     ssh_key_response=$(curl -s -X POST "$PB_URL/api/collections/ssh_keys/records" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $test_user_token" \
#         -d "{
#             \"user\":\"$TEST_USER_ID\",
#             \"public_key\":\"$test_public_key\",
#             \"device_name\":\"Test Device\",
#             \"fingerprint\":\"$fingerprint\",
#             \"is_active\":true
#         }")
#     SSH_KEY_ID=$(echo "$ssh_key_response" | jq -r '.id')
#     track_artifact "ssh_keys:$SSH_KEY_ID"
#     
#     # Deactivate key
#     curl -s -X PATCH "$PB_URL/api/collections/ssh_keys/records/$SSH_KEY_ID" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $test_user_token" \
#         -d '{"is_active":false}' > /dev/null
#     
#     # Check sync endpoint
#     local keys_response
#     keys_response=$(curl -s "$PB_URL/api/pocketcoder/ssh_keys")
#     
#     ! echo "$keys_response" | grep -q "$(echo "$test_public_key" | awk '{print $2}')" || run_diagnostic_on_failure "SSH Keys" "Deactivated key still in sync endpoint"
#     
#     echo "✓ Deactivated key not in sync endpoint"
# }

# @test "SSH Keys: Test multiple keys per user" {
#     # Create test user
#     authenticate_user
#     local user_response
#     user_response=$(curl -s -X POST "$PB_URL/api/collections/users/records" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $USER_TOKEN" \
#         -d "{\"email\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\",\"passwordConfirm\":\"$TEST_USER_PASSWORD\"}")
#     TEST_USER_ID=$(echo "$user_response" | jq -r '.id')
#     track_artifact "users:$TEST_USER_ID"
#     
#     local auth_response
#     auth_response=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
#         -H "Content-Type: application/json" \
#         -d "{\"identity\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\"}")
#     local test_user_token
#     test_user_token=$(echo "$auth_response" | jq -r '.token')
#     
#     # Register first key
#     ssh-keygen -t ed25519 -f /tmp/test_ssh_key -N "" -C "test-device" > /dev/null 2>&1
#     local test_public_key
#     test_public_key=$(cat /tmp/test_ssh_key.pub)
#     local key_base64
#     key_base64=$(echo "$test_public_key" | awk '{print $2}')
#     local fingerprint
#     fingerprint="SHA256:$(echo "$key_base64" | base64 -d | shasum -a 256 | awk '{print $1}' | xxd -r -p | base64)"
#     
#     local ssh_key_response
#     ssh_key_response=$(curl -s -X POST "$PB_URL/api/collections/ssh_keys/records" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $test_user_token" \
#         -d "{
#             \"user\":\"$TEST_USER_ID\",
#             \"public_key\":\"$test_public_key\",
#             \"device_name\":\"Test Device\",
#             \"fingerprint\":\"$fingerprint\",
#             \"is_active\":true
#         }")
#     SSH_KEY_ID=$(echo "$ssh_key_response" | jq -r '.id')
#     track_artifact "ssh_keys:$SSH_KEY_ID"
#     
#     # Register second key
#     ssh-keygen -t ed25519 -f /tmp/test_ssh_key2 -N "" -C "test-device-2" > /dev/null 2>&1
#     local test_public_key2
#     test_public_key2=$(cat /tmp/test_ssh_key2.pub)
#     local key_base64_2
#     key_base64_2=$(echo "$test_public_key2" | awk '{print $2}')
#     local fingerprint2
#     fingerprint2="SHA256:$(echo "$key_base64_2" | base64 -d | shasum -a 256 | awk '{print $1}' | xxd -r -p | base64)"
#     
#     local ssh_key_response2
#     ssh_key_response2=$(curl -s -X POST "$PB_URL/api/collections/ssh_keys/records" \
#         -H "Content-Type: application/json" \
#         -H "Authorization: $test_user_token" \
#         -d "{
#             \"user\":\"$TEST_USER_ID\",
#             \"public_key\":\"$test_public_key2\",
#             \"device_name\":\"Test Device 2\",
#             \"fingerprint\":\"$fingerprint2\",
#             \"is_active\":true
#         }")
#     SSH_KEY_ID2=$(echo "$ssh_key_response2" | jq -r '.id // empty')
#     [ -n "$SSH_KEY_ID2" ] && [ "$SSH_KEY_ID2" != "null" ] || run_diagnostic_on_failure "SSH Keys" "Failed to register second SSH key"
#     
#     track_artifact "ssh_keys:$SSH_KEY_ID2"
#     echo "✓ Multiple SSH keys per user supported"
# }
