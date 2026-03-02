#!/usr/bin/env bats
# Feature: LLM Provider/API Key Management
#
# Integration tests for LLM key management, provider sync, and model switching.
#
# Tests:
# 1. Collections exist with correct fields
# 2. llm_keys CRUD with owner access control
# 3. Go hook renders llm.env on key save/delete
# 4. Go hook restarts OpenCode container on key change
# 5. Provider sync populates llm_providers from OpenCode
# 6. Model switch via llm_config triggers interface handling
# 7. Unique constraint on (provider_id, user) in llm_keys
# 8. Unique constraint on (user, chat) in llm_config
# 9. OpenCode entrypoint sources llm.env on startup

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
    USER_TOKEN=""
    USER_ID=""
}

teardown() {
    # Clean up llm_keys records
    if [ -n "$USER_TOKEN" ] && [ -n "$USER_ID" ]; then
        cleanup_llm_keys || true
    fi
    cleanup_llm_config || true
}

# =============================================================================
# Helpers
# =============================================================================

# Clean up llm_keys records for the current user
cleanup_llm_keys() {
    local response
    response=$(curl -s -X GET \
        "$PB_URL/api/collections/llm_keys/records?filter=provider_id~\"$TEST_ID\"" \
        -H "Authorization: $USER_TOKEN")

    echo "$response" | jq -r '.items[]?.id // empty' 2>/dev/null | while read -r id; do
        [ -n "$id" ] && curl -s -X DELETE \
            "$PB_URL/api/collections/llm_keys/records/$id" \
            -H "Authorization: $USER_TOKEN" > /dev/null 2>&1 || true
    done
}

# Clean up llm_config records
cleanup_llm_config() {
    local token
    token=$(get_admin_token 2>/dev/null) || return 0

    local response
    response=$(curl -s -X GET \
        "$PB_URL/api/collections/llm_config/records?filter=model~\"$TEST_ID\"" \
        -H "Authorization: $token")

    echo "$response" | jq -r '.items[]?.id // empty' 2>/dev/null | while read -r id; do
        [ -n "$id" ] && curl -s -X DELETE \
            "$PB_URL/api/collections/llm_config/records/$id" \
            -H "Authorization: $token" > /dev/null 2>&1 || true
    done
}

# Create an llm_keys record; prints JSON response
create_llm_key() {
    local provider_id="$1"
    local env_vars="$2"
    local token="${3:-$USER_TOKEN}"
    local user="${4:-$USER_ID}"

    curl -s -X POST "$PB_URL/api/collections/llm_keys/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $token" \
        -d "{
            \"provider_id\": \"$provider_id\",
            \"env_vars\": $env_vars,
            \"user\": \"$user\"
        }"
}

# =============================================================================
# 1. Collections Exist
# =============================================================================

@test "LLM Collections: llm_keys exists with correct fields" {
    authenticate_superuser

    local response
    response=$(curl -s "$PB_URL/api/collections/llm_keys" \
        -H "Authorization: $USER_TOKEN")

    local name
    name=$(echo "$response" | jq -r '.name // empty')
    [ "$name" = "llm_keys" ] || {
        echo "❌ llm_keys collection not found. Response: $response" >&2
        return 1
    }

    # Verify required fields exist
    local fields
    fields=$(echo "$response" | jq -r '[.fields[].name] | join(",")')
    echo "$fields" | grep -q "provider_id" || { echo "❌ Missing field: provider_id" >&2; return 1; }
    echo "$fields" | grep -q "env_vars" || { echo "❌ Missing field: env_vars" >&2; return 1; }
    echo "$fields" | grep -q "user" || { echo "❌ Missing field: user" >&2; return 1; }

    echo "✓ llm_keys collection exists with fields: $fields"
}

@test "LLM Collections: llm_config exists with correct fields" {
    authenticate_superuser

    local response
    response=$(curl -s "$PB_URL/api/collections/llm_config" \
        -H "Authorization: $USER_TOKEN")

    local name
    name=$(echo "$response" | jq -r '.name // empty')
    [ "$name" = "llm_config" ] || {
        echo "❌ llm_config collection not found" >&2
        return 1
    }

    local fields
    fields=$(echo "$response" | jq -r '[.fields[].name] | join(",")')
    echo "$fields" | grep -q "model" || { echo "❌ Missing field: model" >&2; return 1; }
    echo "$fields" | grep -q "user" || { echo "❌ Missing field: user" >&2; return 1; }
    echo "$fields" | grep -q "chat" || { echo "❌ Missing field: chat" >&2; return 1; }

    echo "✓ llm_config collection exists with fields: $fields"
}

@test "LLM Collections: llm_providers exists with correct fields" {
    authenticate_superuser

    local response
    response=$(curl -s "$PB_URL/api/collections/llm_providers" \
        -H "Authorization: $USER_TOKEN")

    local name
    name=$(echo "$response" | jq -r '.name // empty')
    [ "$name" = "llm_providers" ] || {
        echo "❌ llm_providers collection not found" >&2
        return 1
    }

    local fields
    fields=$(echo "$response" | jq -r '[.fields[].name] | join(",")')
    echo "$fields" | grep -q "provider_id" || { echo "❌ Missing field: provider_id" >&2; return 1; }
    echo "$fields" | grep -q "name" || { echo "❌ Missing field: name" >&2; return 1; }
    echo "$fields" | grep -q "env_vars" || { echo "❌ Missing field: env_vars" >&2; return 1; }
    echo "$fields" | grep -q "models" || { echo "❌ Missing field: models" >&2; return 1; }
    echo "$fields" | grep -q "is_connected" || { echo "❌ Missing field: is_connected" >&2; return 1; }

    echo "✓ llm_providers collection exists with fields: $fields"
}

# =============================================================================
# 2. llm_keys CRUD + Access Control
# =============================================================================

@test "LLM Keys: Owner can create and read API key record" {
    authenticate_user

    local response
    response=$(create_llm_key "test-provider-$TEST_ID" '{"TEST_API_KEY": "sk-test-12345"}')

    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] && [ "$record_id" != "null" ] || {
        echo "❌ Failed to create llm_keys record. Response: $response" >&2
        return 1
    }

    # Verify we can read it back
    local get_response
    get_response=$(curl -s "$PB_URL/api/collections/llm_keys/records/$record_id" \
        -H "Authorization: $USER_TOKEN")

    local provider
    provider=$(echo "$get_response" | jq -r '.provider_id // empty')
    [ "$provider" = "test-provider-$TEST_ID" ] || {
        echo "❌ Provider mismatch. Expected: test-provider-$TEST_ID, Got: $provider" >&2
        return 1
    }

    local key_val
    key_val=$(echo "$get_response" | jq -r '.env_vars.TEST_API_KEY // empty')
    [ "$key_val" = "sk-test-12345" ] || {
        echo "❌ env_vars value mismatch. Expected: sk-test-12345, Got: $key_val" >&2
        return 1
    }

    echo "✓ Owner can create and read llm_keys record (id: $record_id)"
}

@test "LLM Keys: Owner can delete API key record" {
    authenticate_user

    # Create
    local response
    response=$(create_llm_key "delete-test-$TEST_ID" '{"DELETE_KEY": "to-be-deleted"}')
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed" >&2; return 1; }

    # Delete
    local del_code
    del_code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        "$PB_URL/api/collections/llm_keys/records/$record_id" \
        -H "Authorization: $USER_TOKEN")
    [ "$del_code" = "204" ] || {
        echo "❌ Delete returned HTTP $del_code, expected 204" >&2
        return 1
    }

    # Verify gone
    local get_code
    get_code=$(curl -s -o /dev/null -w "%{http_code}" \
        "$PB_URL/api/collections/llm_keys/records/$record_id" \
        -H "Authorization: $USER_TOKEN")
    [ "$get_code" = "404" ] || {
        echo "❌ Record still exists after delete (HTTP $get_code)" >&2
        return 1
    }

    echo "✓ Owner can delete llm_keys record"
}

@test "LLM Keys: Unauthenticated request is rejected" {
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        "$PB_URL/api/collections/llm_keys/records" \
        -H "Content-Type: application/json" \
        -d '{"provider_id": "test", "env_vars": {}, "user": "fake"}')

    local http_code
    http_code=$(echo "$response" | tail -n 1)
    [ "$http_code" = "400" ] || [ "$http_code" = "401" ] || [ "$http_code" = "403" ] || {
        echo "❌ Unauthenticated create should fail, got HTTP $http_code" >&2
        return 1
    }

    echo "✓ Unauthenticated llm_keys create rejected (HTTP $http_code)"
}

# =============================================================================
# 3. Go Hook — llm.env Rendering
# =============================================================================

@test "LLM Hook: Saving key renders llm.env with correct content" {
    authenticate_user

    # Create a key
    local response
    response=$(create_llm_key "env-test-$TEST_ID" "{\"ENVTEST_API_KEY_$TEST_ID\": \"sk-env-test-value\"}")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed: $response" >&2; return 1; }

    # Wait for hook to render
    sleep 3

    # Check llm.env inside pocketbase container
    local env_content
    env_content=$(docker exec pocketcoder-pocketbase cat /workspace/.opencode/llm.env 2>&1)

    echo "$env_content" | grep -q "ENVTEST_API_KEY_$TEST_ID=sk-env-test-value" || {
        echo "❌ llm.env does not contain expected key" >&2
        echo "  Expected: ENVTEST_API_KEY_$TEST_ID=sk-env-test-value" >&2
        echo "  Content:" >&2
        echo "$env_content" >&2
        return 1
    }

    echo "✓ llm.env rendered with key after save"
    echo "  Content preview: $(echo "$env_content" | grep -v '^#' | head -3)"
}

@test "LLM Hook: Deleting key removes it from llm.env" {
    authenticate_user

    # Create a key
    local response
    response=$(create_llm_key "delenv-$TEST_ID" "{\"DELENV_KEY_$TEST_ID\": \"sk-delete-me\"}")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed" >&2; return 1; }

    sleep 3

    # Verify it's in llm.env
    local env_before
    env_before=$(docker exec pocketcoder-pocketbase cat /workspace/.opencode/llm.env 2>&1)
    echo "$env_before" | grep -q "DELENV_KEY_$TEST_ID" || {
        echo "❌ Key not in llm.env after create" >&2
        return 1
    }

    # Delete the key
    curl -s -X DELETE "$PB_URL/api/collections/llm_keys/records/$record_id" \
        -H "Authorization: $USER_TOKEN" > /dev/null

    sleep 3

    # Verify it's gone from llm.env
    local env_after
    env_after=$(docker exec pocketcoder-pocketbase cat /workspace/.opencode/llm.env 2>&1)
    if echo "$env_after" | grep -q "DELENV_KEY_$TEST_ID"; then
        echo "❌ Key still in llm.env after delete" >&2
        echo "  Content:" >&2
        echo "$env_after" >&2
        return 1
    fi

    echo "✓ Key removed from llm.env after delete"
}

# =============================================================================
# 4. Go Hook — OpenCode Container Restart
# =============================================================================

@test "LLM Hook: Saving key triggers OpenCode container restart" {
    authenticate_user

    # Record OpenCode's current start time
    local start_before
    start_before=$(docker inspect pocketcoder-opencode --format '{{.State.StartedAt}}')
    [ -n "$start_before" ] || { echo "❌ Could not read OpenCode StartedAt" >&2; return 1; }

    # Create a key to trigger the hook
    local response
    response=$(create_llm_key "restart-$TEST_ID" "{\"RESTART_KEY_$TEST_ID\": \"sk-restart-test\"}")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed" >&2; return 1; }

    # Wait for restart (OpenCode takes ~15s)
    echo "  Waiting for OpenCode restart..."
    local attempts=0
    local max_attempts=20
    local start_after="$start_before"

    while [ "$start_after" = "$start_before" ] && [ $attempts -lt $max_attempts ]; do
        sleep 3
        start_after=$(docker inspect pocketcoder-opencode --format '{{.State.StartedAt}}' 2>/dev/null || echo "$start_before")
        attempts=$((attempts + 1))
    done

    [ "$start_before" != "$start_after" ] || {
        echo "❌ OpenCode was not restarted (StartedAt unchanged after ${max_attempts}x3s)" >&2
        echo "  Before: $start_before" >&2
        echo "  After:  $start_after" >&2
        return 1
    }

    # Verify OpenCode came back healthy
    local oc_status
    attempts=0
    while [ $attempts -lt 20 ]; do
        oc_status=$(docker inspect pocketcoder-opencode --format '{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
        if [ "$oc_status" = "healthy" ]; then
            break
        fi
        sleep 3
        attempts=$((attempts + 1))
    done

    [ "$oc_status" = "healthy" ] || {
        echo "❌ OpenCode not healthy after restart (status: $oc_status)" >&2
        return 1
    }

    echo "✓ OpenCode restarted and healthy after key save"
    echo "  Before: $start_before"
    echo "  After:  $start_after"
}

# =============================================================================
# 5. Provider Sync
# =============================================================================

@test "LLM Providers: Interface syncs providers from OpenCode into llm_providers" {
    authenticate_user

    # Check that llm_providers has been populated by the interface
    local response
    response=$(curl -s "$PB_URL/api/collections/llm_providers/records?perPage=1" \
        -H "Authorization: $USER_TOKEN")

    local total
    total=$(echo "$response" | jq -r '.totalItems // 0')
    [ "$total" -gt 0 ] || {
        echo "❌ llm_providers is empty — interface did not sync providers" >&2
        return 1
    }

    echo "✓ llm_providers populated with $total providers"
}

@test "LLM Providers: Provider records have required fields populated" {
    authenticate_user

    local response
    response=$(curl -s "$PB_URL/api/collections/llm_providers/records?perPage=3" \
        -H "Authorization: $USER_TOKEN")

    local count
    count=$(echo "$response" | jq -r '.items | length')
    [ "$count" -gt 0 ] || { echo "❌ No providers to check" >&2; return 1; }

    # Check first provider has all required fields
    local provider_id name
    provider_id=$(echo "$response" | jq -r '.items[0].provider_id // empty')
    name=$(echo "$response" | jq -r '.items[0].name // empty')

    [ -n "$provider_id" ] || { echo "❌ provider_id is empty" >&2; return 1; }
    [ -n "$name" ] || { echo "❌ name is empty" >&2; return 1; }

    echo "✓ Provider records have required fields (checked: $provider_id / $name)"
}

@test "LLM Providers: Connected providers are marked correctly" {
    authenticate_user

    # At minimum, the built-in 'opencode' provider should be connected
    local response
    response=$(curl -s "$PB_URL/api/collections/llm_providers/records?filter=is_connected%3Dtrue" \
        -H "Authorization: $USER_TOKEN")

    local total
    total=$(echo "$response" | jq -r '.totalItems // 0')
    [ "$total" -ge 1 ] || {
        echo "❌ No connected providers found — expected at least 1" >&2
        return 1
    }

    local connected_names
    connected_names=$(echo "$response" | jq -r '[.items[].provider_id] | join(", ")')

    echo "✓ $total connected provider(s): $connected_names"
}

# =============================================================================
# 6. Model Switch
# =============================================================================

@test "LLM Config: Creating global default model config succeeds" {
    authenticate_user

    local response
    response=$(curl -s -X POST "$PB_URL/api/collections/llm_config/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d "{
            \"model\": \"test-model-$TEST_ID\",
            \"user\": \"$USER_ID\"
        }")

    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] && [ "$record_id" != "null" ] || {
        echo "❌ Failed to create llm_config record. Response: $response" >&2
        return 1
    }

    local model
    model=$(echo "$response" | jq -r '.model // empty')
    [ "$model" = "test-model-$TEST_ID" ] || {
        echo "❌ Model mismatch. Expected: test-model-$TEST_ID, Got: $model" >&2
        return 1
    }

    # Chat should be empty for global default
    local chat
    chat=$(echo "$response" | jq -r '.chat // empty')
    [ -z "$chat" ] || [ "$chat" = "" ] || {
        echo "❌ Global config should have empty chat field, got: $chat" >&2
        return 1
    }

    echo "✓ Global default model config created (id: $record_id, model: $model)"
}

@test "LLM Config: Interface handles global model switch" {
    authenticate_user

    # Create a global model config — interface should pick it up via subscription
    local response
    response=$(curl -s -X POST "$PB_URL/api/collections/llm_config/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d "{
            \"model\": \"switch-test-$TEST_ID\",
            \"user\": \"$USER_ID\"
        }")

    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed" >&2; return 1; }

    # Wait for interface to process
    sleep 3

    # Check interface logs for model switch handling
    local interface_logs
    interface_logs=$(docker logs pocketcoder-interface 2>&1 | tail -20)

    echo "$interface_logs" | grep -q "Updated global default model to 'switch-test-$TEST_ID'" || {
        echo "❌ Interface did not log global model switch" >&2
        echo "  Expected log line containing: Updated global default model to 'switch-test-$TEST_ID'" >&2
        echo "  Recent interface logs:" >&2
        echo "$interface_logs" >&2
        return 1
    }

    echo "✓ Interface handled global model switch to 'switch-test-$TEST_ID'"
}

# =============================================================================
# 7. Unique Constraints
# =============================================================================

@test "LLM Keys: Duplicate (provider_id, user) is rejected" {
    authenticate_user

    # Create first key
    local response1
    response1=$(create_llm_key "unique-$TEST_ID" '{"KEY1": "value1"}')
    local id1
    id1=$(echo "$response1" | jq -r '.id // empty')
    [ -n "$id1" ] || { echo "❌ First create failed" >&2; return 1; }

    # Try to create duplicate
    local response2
    response2=$(curl -s -w "\n%{http_code}" -X POST \
        "$PB_URL/api/collections/llm_keys/records" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d "{
            \"provider_id\": \"unique-$TEST_ID\",
            \"env_vars\": {\"KEY2\": \"value2\"},
            \"user\": \"$USER_ID\"
        }")

    local http_code
    http_code=$(echo "$response2" | tail -n 1)

    # Should fail with 400 (unique constraint violation)
    [ "$http_code" != "200" ] || {
        echo "❌ Duplicate (provider_id, user) should be rejected, but got HTTP 200" >&2
        return 1
    }

    echo "✓ Duplicate (provider_id, user) correctly rejected (HTTP $http_code)"
}

# =============================================================================
# 8. OpenCode Entrypoint Sources llm.env
# =============================================================================

@test "LLM Entrypoint: OpenCode container sources llm.env on startup" {
    # Check that the entrypoint sourced llm.env (look for the log line)
    local logs
    logs=$(docker logs pocketcoder-opencode 2>&1)

    # Should have either "Loading LLM provider keys" or "No llm.env found"
    if echo "$logs" | grep -q "Loading LLM provider keys from llm.env"; then
        echo "✓ OpenCode entrypoint sourced llm.env"
    elif echo "$logs" | grep -q "No llm.env found"; then
        echo "✓ OpenCode entrypoint checked for llm.env (not present yet — expected on fresh start)"
    else
        echo "❌ OpenCode entrypoint did not attempt to source llm.env" >&2
        echo "  Expected one of:" >&2
        echo "    'Loading LLM provider keys from llm.env'" >&2
        echo "    'No llm.env found'" >&2
        echo "  First 10 lines of logs:" >&2
        echo "$logs" | head -10 >&2
        return 1
    fi
}

@test "LLM Entrypoint: API key from llm.env is available in OpenCode process" {
    authenticate_user

    # Create a key so llm.env has content
    local response
    response=$(create_llm_key "proctest-$TEST_ID" "{\"PROCTEST_KEY_$TEST_ID\": \"sk-proc-verify\"}")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed" >&2; return 1; }

    # Wait for hook to render + restart
    echo "  Waiting for OpenCode restart with new env..."
    sleep 20

    # Wait for OpenCode to be healthy again
    local attempts=0
    while [ $attempts -lt 20 ]; do
        local health
        health=$(docker inspect pocketcoder-opencode --format '{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
        if [ "$health" = "healthy" ]; then
            break
        fi
        sleep 3
        attempts=$((attempts + 1))
    done

    # Check if the env var is in the OpenCode main process
    local env_val
    env_val=$(docker exec pocketcoder-opencode /bin/ash -c "cat /proc/1/environ 2>/dev/null | tr '\0' '\n' | grep PROCTEST_KEY_$TEST_ID" || echo "")

    [ -n "$env_val" ] || {
        echo "❌ PROCTEST_KEY_$TEST_ID not found in OpenCode PID 1 environment" >&2
        return 1
    }

    echo "$env_val" | grep -q "sk-proc-verify" || {
        echo "❌ Key value mismatch in process env: $env_val" >&2
        return 1
    }

    echo "✓ API key available in OpenCode process: $env_val"
}

# =============================================================================
# 9. Docker Compose — No Hardcoded Keys
# =============================================================================

@test "LLM Config: GEMINI_API_KEY not hardcoded in OpenCode container env" {
    # Verify the docker-compose change removed hardcoded keys
    # Check the container's config for GEMINI_API_KEY in the defined env
    local env_config
    env_config=$(docker inspect pocketcoder-opencode --format '{{json .Config.Env}}' 2>/dev/null)

    if echo "$env_config" | grep -q "GEMINI_API_KEY"; then
        echo "❌ GEMINI_API_KEY is still hardcoded in OpenCode container env" >&2
        echo "  Config.Env: $env_config" >&2
        return 1
    fi

    echo "✓ GEMINI_API_KEY not hardcoded in OpenCode container (keys come from llm.env)"
}

@test "LLM Config: GEMINI_API_KEY not hardcoded in Sandbox container env" {
    local env_config
    env_config=$(docker inspect pocketcoder-sandbox --format '{{json .Config.Env}}' 2>/dev/null)

    if echo "$env_config" | grep -q "GEMINI_API_KEY"; then
        echo "❌ GEMINI_API_KEY is still hardcoded in Sandbox container env" >&2
        echo "  Config.Env: $env_config" >&2
        return 1
    fi

    echo "✓ GEMINI_API_KEY not hardcoded in Sandbox container (keys come from llm.env)"
}

# =============================================================================
# 10. Shared Volume — Sandbox LLM Keys
# =============================================================================

@test "LLM Shared Volume: Sandbox can read /llm_keys/llm.env" {
    # Verify the shared volume is mounted and readable
    local content
    content=$(docker exec pocketcoder-sandbox cat /llm_keys/llm.env 2>&1)

    echo "$content" | grep -q "PocketCoder LLM Keys" || {
        echo "❌ Sandbox cannot read /llm_keys/llm.env" >&2
        echo "  Output: $content" >&2
        return 1
    }

    echo "✓ Sandbox can read /llm_keys/llm.env"
}

@test "LLM Shared Volume: Key saved in PocketBase appears in sandbox llm.env" {
    authenticate_user

    # Create a key
    local response
    response=$(create_llm_key "sandbox-$TEST_ID" "{\"SANDBOX_KEY_$TEST_ID\": \"sk-sandbox-test\"}")
    local record_id
    record_id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$record_id" ] || { echo "❌ Create failed: $response" >&2; return 1; }

    # Wait for hook to render both files
    sleep 3

    # Check that the key appears in the sandbox's shared volume
    local sandbox_env
    sandbox_env=$(docker exec pocketcoder-sandbox cat /llm_keys/llm.env 2>&1)

    echo "$sandbox_env" | grep -q "SANDBOX_KEY_$TEST_ID=sk-sandbox-test" || {
        echo "❌ Key not found in sandbox /llm_keys/llm.env" >&2
        echo "  Expected: SANDBOX_KEY_$TEST_ID=sk-sandbox-test" >&2
        echo "  Content:" >&2
        echo "$sandbox_env" >&2
        return 1
    }

    echo "✓ Key from PocketBase visible in sandbox /llm_keys/llm.env"
}

@test "LLM Shared Volume: Sandbox llm.env matches OpenCode llm.env" {
    # Both files should have identical content
    local opencode_env sandbox_env
    opencode_env=$(docker exec pocketcoder-pocketbase cat /workspace/.opencode/llm.env 2>&1)
    sandbox_env=$(docker exec pocketcoder-sandbox cat /llm_keys/llm.env 2>&1)

    [ "$opencode_env" = "$sandbox_env" ] || {
        echo "❌ llm.env files differ between OpenCode and sandbox paths" >&2
        echo "  OpenCode:" >&2
        echo "$opencode_env" >&2
        echo "  Sandbox:" >&2
        echo "$sandbox_env" >&2
        return 1
    }

    echo "✓ OpenCode and sandbox llm.env files are identical"
}

@test "LLM Shared Volume: Sandbox mount is read-only" {
    # Attempt to write should fail since sandbox has :ro mount
    # docker exec may return non-zero when the shell command fails, which is expected
    local write_result
    write_result=$(docker exec pocketcoder-sandbox sh -c 'echo "test" > /llm_keys/test.txt 2>&1 || echo "WRITE_FAILED"' 2>&1)
    local exit_code=$?

    # The write should fail — check for read-only error or WRITE_FAILED marker
    if echo "$write_result" | grep -qi "read-only\|WRITE_FAILED"; then
        echo "✓ Sandbox /llm_keys mount is read-only (write correctly rejected)"
        return 0
    fi

    # If exit code is non-zero, the write also failed
    if [ $exit_code -ne 0 ]; then
        echo "✓ Sandbox /llm_keys mount is read-only (docker exec returned $exit_code)"
        return 0
    fi

    # Last resort: verify the file was not actually written
    if docker exec pocketcoder-sandbox test -f /llm_keys/test.txt 2>/dev/null; then
        echo "❌ Sandbox was able to write to /llm_keys — mount should be read-only" >&2
        docker exec pocketcoder-sandbox rm -f /llm_keys/test.txt 2>/dev/null
        return 1
    fi

    echo "✓ Sandbox /llm_keys mount is read-only"
}
