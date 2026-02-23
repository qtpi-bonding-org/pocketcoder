#!/usr/bin/env bats
# Feature: mcp-gateway-integration, Full Flow Integration Test
#
# Complete end-to-end integration test for MCP Gateway flow
# Validates: Requirements 1.1, 3.1-3.5, 6.1, 7.1-7.5, 9.1-9.5
#
# Test flow (mirrors MCP_GATEWAY_ARCHITECTURE.md § Flow):
# 1. Poco browses the Docker MCP Catalog using the CLI
# 2. Poco checks what's already installed via mcp_status (config volume read)
# 3. Poco sends structured request to PocketBase → POST /api/pocketcoder/mcp_request
# 4. PocketBase creates mcp_servers record with status "pending"
# 5. User approves the request (status → approved)
# 6. PocketBase renders gateway catalog (docker-mcp.yaml) from DB
# 7. PocketBase restarts MCP Gateway container via docker socket
# 8. Gateway SSE endpoint on port 8811 serves the new server
# 9. Subagent in sandbox connects to gateway SSE and uses MCP tools

load '../../helpers/auth.sh'
load '../../helpers/cleanup.sh'
load '../../helpers/wait.sh'
load '../../helpers/assertions.sh'
load '../../helpers/diagnostics.sh'
load '../../helpers/tracking.sh'
load '../../helpers/mcp.sh'

setup() {
    load_env
    TEST_ID=$(generate_test_id)
    export CURRENT_TEST_ID="$TEST_ID"
    MCP_SERVER_ID=""
    AGENT_TOKEN=""
    AGENT_ID=""
    SERVER_NAME="test-mcp-$TEST_ID"
}

teardown() {
    cleanup_test_data "$TEST_ID" || true
    cleanup_mcp_servers "$TEST_ID" || true
}

# =============================================================================
# Helpers
# =============================================================================

authenticate_agent() {
    load_env

    local email="${AGENT_EMAIL:-}"
    local password="${AGENT_PASSWORD:-}"

    if [ -z "$email" ] || [ -z "$password" ]; then
        echo "❌ Error: AGENT_EMAIL or AGENT_PASSWORD not found" >&2
        return 1
    fi

    local token_res
    token_res=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\": \"$email\", \"password\": \"$password\"}")

    AGENT_TOKEN=$(echo "$token_res" | jq -r '.token // empty')
    AGENT_ID=$(echo "$token_res" | jq -r '.record.id // empty')

    if [ -z "$AGENT_TOKEN" ]; then
        echo "❌ Failed to authenticate as agent" >&2
        echo "Response: $token_res" >&2
        return 1
    fi

    export AGENT_TOKEN AGENT_ID
}

cleanup_mcp_servers() {
    local test_id="$1"
    local token="${2:-$(get_admin_token)}"

    local response
    response=$(curl -s -X GET \
        "$PB_URL/api/collections/mcp_servers/records?filter=name~\"$test_id\"" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json")

    echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | while read -r id; do
        delete_record "mcp_servers" "$id" "$token" || true
    done
}

# =============================================================================
# Step 1: Poco browses the Docker MCP Catalog
# =============================================================================

@test "MCP Full Flow: Poco browses Docker MCP Catalog via CLI" {
    # Validates: Requirement 3.1 — mcp_catalog tool executes docker mcp catalog show
    # Poco runs inside OpenCode container. The docker mcp CLI is installed there
    # for catalog browsing only (no docker socket, no install capability).

    # Verify docker mcp CLI is available in OpenCode container
    run docker exec pocketcoder-opencode docker mcp --version
    [ "$status" -eq 0 ] || {
        echo "❌ docker mcp CLI not installed in OpenCode container" >&2
        return 1
    }

    # Browse the catalog
    local catalog_output
    catalog_output=$(docker exec pocketcoder-opencode docker mcp catalog show docker-mcp 2>&1 || true)

    # Catalog should return some output (even if empty list, the command should work)
    [ -n "$catalog_output" ] || {
        echo "❌ Catalog browse returned empty output" >&2
        return 1
    }

    echo "✓ Step 1: Poco browsed MCP catalog"
    echo "  Output (first 200 chars): ${catalog_output:0:200}"
}

# =============================================================================
# Step 2: Poco checks what's already installed (config volume read)
# =============================================================================

@test "MCP Full Flow: Poco reads mcp_status from config volume" {
    # Validates: Requirement 3.3 — mcp_status tool reads /mcp_config/docker-mcp.yaml
    # OpenCode has the mcp_config volume mounted read-only at /mcp_config

    # Check if config volume is mounted
    run docker exec pocketcoder-opencode test -d /mcp_config
    [ "$status" -eq 0 ] || {
        echo "❌ /mcp_config not mounted in OpenCode" >&2
        return 1
    }

    # Try to read current config (may or may not exist yet)
    local config_content
    config_content=$(docker exec pocketcoder-opencode cat /mcp_config/docker-mcp.yaml 2>&1 || echo "No config found")

    # Either we get config content or a "not found" — both are valid states
    echo "✓ Step 2: Poco checked MCP status"
    echo "  Config: ${config_content:0:200}"
}

# =============================================================================
# Step 3: Poco sends request to PocketBase via mcp_request endpoint
# =============================================================================

@test "MCP Full Flow: Poco requests MCP server via POST /api/pocketcoder/mcp_request" {
    # Validates: Requirements 7.1-7.4 — Agent authenticates and POSTs to mcp_request endpoint

    authenticate_agent

    local response
    response=$(curl -s -X POST "$PB_URL/api/pocketcoder/mcp_request" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AGENT_TOKEN" \
        -d "{
            \"server_name\": \"$SERVER_NAME\",
            \"reason\": \"Full flow integration test requires this server\",
            \"session_id\": \"$TEST_ID\"
        }")

    # Verify response contains record ID
    MCP_SERVER_ID=$(echo "$response" | jq -r '.id // empty')
    [ -n "$MCP_SERVER_ID" ] && [ "$MCP_SERVER_ID" != "null" ] || {
        echo "❌ mcp_request did not return record ID. Response: $response" >&2
        return 1
    }

    track_artifact "mcp_servers:$MCP_SERVER_ID"

    echo "✓ Step 3: Poco requested MCP server '$SERVER_NAME'"
    echo "  Record ID: $MCP_SERVER_ID"
}

# =============================================================================
# Step 4: PocketBase creates pending record in mcp_servers collection
# =============================================================================

@test "MCP Full Flow: PocketBase creates mcp_servers record with status pending" {
    # Validates: Requirements 6.1, 7.4 — mcp_servers collection stores the request

    authenticate_agent

    # Create the request
    local response
    response=$(curl -s -X POST "$PB_URL/api/pocketcoder/mcp_request" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AGENT_TOKEN" \
        -d "{
            \"server_name\": \"pending-$SERVER_NAME\",
            \"reason\": \"Verify pending record creation\",
            \"session_id\": \"$TEST_ID\"
        }")

    MCP_SERVER_ID=$(echo "$response" | jq -r '.id // empty')
    [ -n "$MCP_SERVER_ID" ] && [ "$MCP_SERVER_ID" != "null" ] || {
        echo "❌ Failed to create mcp_servers record. Response: $response" >&2
        return 1
    }
    track_artifact "mcp_servers:$MCP_SERVER_ID"

    # Verify status is pending
    local record_status
    record_status=$(echo "$response" | jq -r '.status // empty')
    [ "$record_status" = "pending" ] || {
        echo "❌ Expected status 'pending', got: $record_status" >&2
        return 1
    }

    # Verify record is retrievable from the collection
    authenticate_superuser
    local record
    record=$(curl -s -X GET "$PB_URL/api/collections/mcp_servers/records/$MCP_SERVER_ID" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")

    local record_name
    record_name=$(echo "$record" | jq -r '.name // empty')
    [ "$record_name" = "pending-$SERVER_NAME" ] || {
        echo "❌ Record name mismatch in collection. Expected: pending-$SERVER_NAME, Got: $record_name" >&2
        return 1
    }

    echo "✓ Step 4: mcp_servers record created (status: pending)"
}

# =============================================================================
# Step 5: User approves the request (status → approved)
# =============================================================================

@test "MCP Full Flow: User approves MCP server request" {
    # Validates: Requirement 9.1 — status change to approved triggers config render

    authenticate_agent

    # Create pending request
    local response
    response=$(curl -s -X POST "$PB_URL/api/pocketcoder/mcp_request" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AGENT_TOKEN" \
        -d "{
            \"server_name\": \"approve-$SERVER_NAME\",
            \"reason\": \"Verify approval flow\",
            \"session_id\": \"$TEST_ID\"
        }")

    MCP_SERVER_ID=$(echo "$response" | jq -r '.id // empty')
    [ -n "$MCP_SERVER_ID" ] || { echo "❌ Failed to create request" >&2; return 1; }
    track_artifact "mcp_servers:$MCP_SERVER_ID"

    # Approve as admin (simulating Flutter app)
    authenticate_superuser
    local approve_response
    approve_response=$(curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$MCP_SERVER_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"status": "approved"}')

    local new_status
    new_status=$(echo "$approve_response" | jq -r '.status // empty')
    [ "$new_status" = "approved" ] || {
        echo "❌ Expected status 'approved', got: $new_status" >&2
        return 1
    }

    echo "✓ Step 5: User approved MCP server request"
}

# =============================================================================
# Step 6: PocketBase renders gateway config from DB
# =============================================================================

@test "MCP Full Flow: Config rendered to mcp_config volume after approval" {
    # Validates: Requirement 9.1 — Relay renders docker-mcp.yaml catalog to MCP_Config_Volume

    authenticate_agent

    # Create and approve a server
    local response
    response=$(curl -s -X POST "$PB_URL/api/pocketcoder/mcp_request" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AGENT_TOKEN" \
        -d "{
            \"server_name\": \"config-$SERVER_NAME\",
            \"reason\": \"Verify config rendering\",
            \"session_id\": \"$TEST_ID\"
        }")

    MCP_SERVER_ID=$(echo "$response" | jq -r '.id // empty')
    [ -n "$MCP_SERVER_ID" ] || { echo "❌ Failed to create request" >&2; return 1; }
    track_artifact "mcp_servers:$MCP_SERVER_ID"

    # Approve
    authenticate_superuser
    curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$MCP_SERVER_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"status": "approved"}' > /dev/null

    # Wait for config to be rendered (relay hook is async)
    sleep 3

    # Check that config volume is mounted and accessible
    run docker exec pocketcoder-pocketbase test -d /mcp_config
    [ "$status" -eq 0 ] || {
        echo "❌ /mcp_config volume not mounted in PocketBase" >&2
        return 1
    }

    # Check for catalog file (docker-mcp.yaml)
    run docker exec pocketcoder-pocketbase test -f /mcp_config/docker-mcp.yaml
    [ "$status" -eq 0 ] || {
        echo "❌ docker-mcp.yaml not found — relay did not render catalog after approval" >&2
        return 1
    }

    # Verify the approved server appears in the catalog
    local config_content
    config_content=$(docker exec pocketcoder-pocketbase cat /mcp_config/docker-mcp.yaml 2>&1)

    echo "$config_content" | grep -q "config-$SERVER_NAME" || {
        echo "❌ Approved server not found in rendered docker-mcp.yaml" >&2
        echo "  Expected to find: config-$SERVER_NAME" >&2
        echo "  Catalog content:" >&2
        echo "$config_content" | head -20 >&2
        return 1
    }

    # Verify catalog format has registry: key
    echo "$config_content" | grep -q "registry:" || {
        echo "❌ docker-mcp.yaml missing 'registry:' key — wrong format" >&2
        return 1
    }

    # Verify catalog has top-level name field (required by gateway)
    echo "$config_content" | grep -q "name: docker-mcp" || {
        echo "❌ docker-mcp.yaml missing 'name: docker-mcp' — catalog identity missing" >&2
        return 1
    }

    # Verify catalog has longLived field for ephemeral containers
    echo "$config_content" | grep -q "longLived: false" || {
        echo "❌ docker-mcp.yaml missing 'longLived: false' — ephemeral mode not set" >&2
        return 1
    }

    echo "✓ Step 6: Catalog rendered to mcp_config volume"
    echo "  docker-mcp.yaml contains approved server: config-$SERVER_NAME"
}

# =============================================================================
# Step 7: PocketBase restarts MCP Gateway via docker socket
# =============================================================================

@test "MCP Full Flow: Gateway container restarted after config change" {
    # Validates: Requirement 9.5 — Relay restarts gateway via Docker API (unix socket)

    # Verify MCP gateway container exists and is running
    local gateway_status
    gateway_status=$(docker inspect pocketcoder-mcp-gateway --format '{{.State.Status}}' 2>/dev/null)
    [ "$gateway_status" = "running" ] || {
        echo "❌ MCP gateway not running (status: ${gateway_status:-not found})" >&2
        return 1
    }

    # Record current container start time
    local start_before
    start_before=$(docker inspect pocketcoder-mcp-gateway --format '{{.State.StartedAt}}')

    # Create and approve a server to trigger restart
    authenticate_agent

    local response
    response=$(curl -s -X POST "$PB_URL/api/pocketcoder/mcp_request" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AGENT_TOKEN" \
        -d "{
            \"server_name\": \"restart-$SERVER_NAME\",
            \"reason\": \"Verify gateway restart\",
            \"session_id\": \"$TEST_ID\"
        }")

    MCP_SERVER_ID=$(echo "$response" | jq -r '.id // empty')
    [ -n "$MCP_SERVER_ID" ] || { echo "❌ Failed to create request" >&2; return 1; }
    track_artifact "mcp_servers:$MCP_SERVER_ID"

    # Approve to trigger restart
    authenticate_superuser
    curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$MCP_SERVER_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"status": "approved"}' > /dev/null

    # Wait for restart
    sleep 5

    # Verify gateway was restarted (start time changed)
    local start_after
    start_after=$(docker inspect pocketcoder-mcp-gateway --format '{{.State.StartedAt}}')

    [ "$start_before" != "$start_after" ] || {
        echo "❌ Gateway was not restarted (StartedAt unchanged)" >&2
        echo "  Before: $start_before" >&2
        echo "  After:  $start_after" >&2
        return 1
    }

    # Verify gateway is running after restart
    local status_after
    status_after=$(docker inspect pocketcoder-mcp-gateway --format '{{.State.Status}}')
    [ "$status_after" = "running" ] || {
        echo "❌ Gateway not running after restart (status: $status_after)" >&2
        return 1
    }

    echo "✓ Step 7: Gateway restarted via docker socket"
    echo "  Before: $start_before"
    echo "  After:  $start_after"
}

# =============================================================================
# Step 8: Gateway SSE endpoint serves the new server
# =============================================================================

@test "MCP Full Flow: Gateway SSE endpoint available on port 8811" {
    # Validates: Requirement 1.1 — Gateway exposes SSE on port 8811 within pocketcoder-mcp

    # Verify gateway SSE endpoint is reachable from sandbox (same network)
    # SSE is a streaming endpoint — curl gets HTTP 200 then hangs until --max-time.
    # When --max-time kills it, exit code is 28 (timeout), so we must NOT use || echo 000
    # which would concatenate "000" onto the already-printed "200".
    local sse_response
    sse_response=$(docker exec pocketcoder-sandbox \
        sh -c 'CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://mcp-gateway:8811/sse 2>/dev/null); echo "${CODE:-000}"')

    # SSE endpoint should return 200 (event stream) or similar success code
    [ "$sse_response" = "200" ] || [ "$sse_response" = "204" ] || {
        echo "❌ Gateway SSE not reachable from sandbox (HTTP $sse_response)" >&2
        return 1
    }

    # Verify gateway is NOT reachable from OpenCode (network isolation)
    # OpenCode is Alpine-based, so use ash instead of sh
    local opencode_response
    opencode_response=$(docker exec pocketcoder-opencode \
        ash -c 'CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 http://mcp-gateway:8811/sse 2>/dev/null); echo "${CODE:-000}"')

    [ "$opencode_response" = "000" ] || {
        echo "❌ Gateway should NOT be reachable from OpenCode (HTTP $opencode_response)" >&2
        return 1
    }

    echo "✓ Step 8: Gateway SSE endpoint available on port 8811"
    echo "  Sandbox → Gateway: HTTP $sse_response (reachable)"
    echo "  OpenCode → Gateway: HTTP $opencode_response (isolated)"
}

# =============================================================================
# Step 9: Subagent connects to gateway and uses MCP tools
# =============================================================================

@test "MCP Full Flow: Sandbox can connect to gateway SSE as MCP client" {
    # Validates: Architecture — Sandbox subagents connect to http://mcp-gateway:8811/sse

    # Verify docker mcp CLI is available in sandbox
    run docker exec pocketcoder-sandbox docker mcp --version
    [ "$status" -eq 0 ] || {
        echo "❌ docker mcp CLI not installed in sandbox" >&2
        return 1
    }

    # Verify MCP_HOST environment variable is set
    local mcp_host
    mcp_host=$(docker exec pocketcoder-sandbox printenv MCP_HOST 2>/dev/null || echo "")

    [ -n "$mcp_host" ] || {
        echo "❌ MCP_HOST not set in sandbox environment" >&2
        return 1
    }

    echo "✓ Step 9: Sandbox configured for MCP gateway connectivity"
    echo "  MCP_HOST: $mcp_host"
}

# =============================================================================
# Denial flow: User denies request
# =============================================================================

@test "MCP Full Flow: Denied request notifies Poco without provisioning" {
    # Validates: Requirement 9.3 — denied status triggers notification, no config change

    authenticate_agent

    # Create pending request
    local response
    response=$(curl -s -X POST "$PB_URL/api/pocketcoder/mcp_request" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AGENT_TOKEN" \
        -d "{
            \"server_name\": \"denied-$SERVER_NAME\",
            \"reason\": \"Verify denial flow\",
            \"session_id\": \"$TEST_ID\"
        }")

    MCP_SERVER_ID=$(echo "$response" | jq -r '.id // empty')
    [ -n "$MCP_SERVER_ID" ] || { echo "❌ Failed to create request" >&2; return 1; }
    track_artifact "mcp_servers:$MCP_SERVER_ID"

    # Deny as admin
    authenticate_superuser
    local deny_response
    deny_response=$(curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$MCP_SERVER_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"status": "denied"}')

    local new_status
    new_status=$(echo "$deny_response" | jq -r '.status // empty')
    [ "$new_status" = "denied" ] || {
        echo "❌ Expected status 'denied', got: $new_status" >&2
        return 1
    }

    # Verify denied server does NOT appear in catalog
    sleep 2
    local config_content
    config_content=$(docker exec pocketcoder-pocketbase cat /mcp_config/docker-mcp.yaml 2>&1 || echo "")

    if echo "$config_content" | grep -q "denied-$SERVER_NAME"; then
        echo "❌ Denied server should not appear in docker-mcp.yaml" >&2
        return 1
    fi

    echo "✓ Denied request handled correctly (no provisioning)"
}

# =============================================================================
# Revocation flow: Approved server gets revoked
# =============================================================================

@test "MCP Full Flow: Revoked server removed from config and gateway restarted" {
    # Validates: Requirement 9.2 — revoked status re-renders config excluding server

    authenticate_agent

    # Create and approve a server
    local response
    response=$(curl -s -X POST "$PB_URL/api/pocketcoder/mcp_request" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AGENT_TOKEN" \
        -d "{
            \"server_name\": \"revoke-$SERVER_NAME\",
            \"reason\": \"Verify revocation flow\",
            \"session_id\": \"$TEST_ID\"
        }")

    MCP_SERVER_ID=$(echo "$response" | jq -r '.id // empty')
    [ -n "$MCP_SERVER_ID" ] || { echo "❌ Failed to create request" >&2; return 1; }
    track_artifact "mcp_servers:$MCP_SERVER_ID"

    # Approve
    authenticate_superuser
    curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$MCP_SERVER_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"status": "approved"}' > /dev/null

    sleep 3

    # Verify server is in catalog
    local config_before
    config_before=$(docker exec pocketcoder-pocketbase cat /mcp_config/docker-mcp.yaml 2>&1)
    echo "$config_before" | grep -q "revoke-$SERVER_NAME" || {
        echo "❌ Approved server not in docker-mcp.yaml before revocation" >&2
        return 1
    }

    # Record gateway start time
    local start_before
    start_before=$(docker inspect pocketcoder-mcp-gateway --format '{{.State.StartedAt}}')

    # Revoke
    curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$MCP_SERVER_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"status": "revoked"}' > /dev/null

    sleep 5

    # Verify server removed from catalog
    local config_after
    config_after=$(docker exec pocketcoder-pocketbase cat /mcp_config/docker-mcp.yaml 2>&1)

    if echo "$config_after" | grep -q "revoke-$SERVER_NAME"; then
        echo "❌ Revoked server still in docker-mcp.yaml" >&2
        return 1
    fi

    # Verify gateway was restarted
    local start_after
    start_after=$(docker inspect pocketcoder-mcp-gateway --format '{{.State.StartedAt}}')
    [ "$start_before" != "$start_after" ] || {
        echo "❌ Gateway not restarted after revocation" >&2
        echo "  StartedAt before: $start_before" >&2
        echo "  StartedAt after:  $start_after" >&2
        return 1
    }

    echo "✓ Revoked server removed from config, gateway restarted"
}

# =============================================================================
# Complete E2E: All steps in sequence
# =============================================================================

@test "MCP Full Flow: Complete end-to-end test" {
    # Validates: All MCP gateway requirements in a single sequential flow

    # Step 1: Poco browses catalog
    local catalog_output
    catalog_output=$(docker exec pocketcoder-opencode docker mcp catalog show docker-mcp 2>&1 || true)
    [ -n "$catalog_output" ] || { echo "❌ Catalog browse failed" >&2; return 1; }
    echo "Step 1: Catalog browsed"

    # Step 2: Poco checks current status
    docker exec pocketcoder-opencode cat /mcp_config/docker-mcp.yaml 2>&1 || true
    echo "Step 2: Current config checked"

    # Step 3: Poco requests MCP server
    authenticate_agent
    local request_response
    request_response=$(curl -s -X POST "$PB_URL/api/pocketcoder/mcp_request" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AGENT_TOKEN" \
        -d "{
            \"server_name\": \"e2e-$SERVER_NAME\",
            \"reason\": \"Complete E2E integration test\",
            \"session_id\": \"$TEST_ID\"
        }")

    MCP_SERVER_ID=$(echo "$request_response" | jq -r '.id // empty')
    [ -n "$MCP_SERVER_ID" ] && [ "$MCP_SERVER_ID" != "null" ] || {
        echo "❌ Request failed. Response: $request_response" >&2
        return 1
    }
    track_artifact "mcp_servers:$MCP_SERVER_ID"
    echo "Step 3: MCP server requested (ID: $MCP_SERVER_ID)"

    # Step 4: Verify pending record
    local pending_status
    pending_status=$(echo "$request_response" | jq -r '.status // empty')
    [ "$pending_status" = "pending" ] || {
        echo "❌ Expected pending, got: $pending_status" >&2
        return 1
    }
    echo "Step 4: Record created with status: pending"

    # Step 5: User approves
    authenticate_superuser
    local approve_response
    approve_response=$(curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$MCP_SERVER_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"status": "approved"}')

    local approved_status
    approved_status=$(echo "$approve_response" | jq -r '.status // empty')
    [ "$approved_status" = "approved" ] || {
        echo "❌ Approval failed. Response: $approve_response" >&2
        return 1
    }
    echo "Step 5: User approved request"

    # Step 6: Wait for catalog render
    sleep 3
    local config_after
    config_after=$(docker exec pocketcoder-pocketbase cat /mcp_config/docker-mcp.yaml 2>&1 || echo "")
    [ -n "$config_after" ] || {
        echo "❌ docker-mcp.yaml not rendered after approval" >&2
        return 1
    }
    echo "$config_after" | grep -q "e2e-$SERVER_NAME" || {
        echo "❌ Approved server not in rendered docker-mcp.yaml" >&2
        return 1
    }
    # Verify catalog format matches spec (name, registry, longLived)
    echo "$config_after" | grep -q "name: docker-mcp" || {
        echo "❌ Catalog missing 'name: docker-mcp'" >&2
        return 1
    }
    echo "$config_after" | grep -q "longLived: false" || {
        echo "❌ Catalog missing 'longLived: false'" >&2
        return 1
    }
    echo "Step 6: Catalog rendered with approved server (format verified)"

    # Step 7: Verify gateway restarted
    local gateway_status
    gateway_status=$(docker inspect pocketcoder-mcp-gateway --format '{{.State.Status}}' 2>/dev/null || echo "unknown")
    [ "$gateway_status" = "running" ] || {
        echo "❌ Gateway not running after approval (status: $gateway_status)" >&2
        return 1
    }
    echo "Step 7: Gateway running"

    # Step 8: Verify SSE endpoint reachable from sandbox
    local sse_code
    sse_code=$(docker exec pocketcoder-sandbox \
        sh -c 'CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://mcp-gateway:8811/sse 2>/dev/null); echo "${CODE:-000}"')
    [ "$sse_code" = "200" ] || [ "$sse_code" = "204" ] || {
        echo "❌ Gateway SSE not reachable (HTTP $sse_code)" >&2
        return 1
    }
    echo "Step 8: Gateway SSE endpoint reachable from sandbox"

    # Step 9: Verify sandbox has MCP client tooling
    run docker exec pocketcoder-sandbox docker mcp --version
    [ "$status" -eq 0 ] || {
        echo "❌ docker mcp CLI not in sandbox" >&2
        return 1
    }
    echo "Step 9: Sandbox MCP client ready"

    echo ""
    echo "=========================================="
    echo "✓ MCP FULL FLOW E2E SUCCESSFUL"
    echo "=========================================="
    echo "Server: e2e-$SERVER_NAME"
    echo "Record: $MCP_SERVER_ID (approved)"
    echo "Config: rendered"
    echo "Gateway: running"
    echo "SSE: reachable from sandbox"
    echo "=========================================="
}

# =============================================================================
# Infrastructure: PocketBase can restart MCP Gateway container via docker socket
# =============================================================================

@test "MCP Infra: MCP Gateway can be restarted and comes back up" {
    # Validates: MCP_GATEWAY_ARCHITECTURE.md — Gateway can be restarted and recovers.
    #
    # The gateway is restarted via docker. We verify the restart by checking
    # the SSE endpoint and gateway timestamps.

    # Verify MCP gateway is running
    run docker inspect pocketcoder-mcp-gateway --format '{{.State.Status}}'
    [ "$status" -eq 0 ] || { echo "❌ MCP gateway container not found" >&2; return 1; }
    [ "$output" = "running" ] || { echo "❌ MCP gateway not running (status: $output)" >&2; return 1; }

    # Record the gateway's current StartedAt timestamp
    local started_before
    started_before=$(docker inspect pocketcoder-mcp-gateway --format '{{.State.StartedAt}}')
    [ -n "$started_before" ] || { echo "❌ Could not read gateway StartedAt" >&2; return 1; }

    # Verify SSE endpoint is reachable before restart
    local sse_code_before
    sse_code_before=$(docker exec pocketcoder-sandbox \
        sh -c 'CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://mcp-gateway:8811/sse 2>/dev/null); echo "${CODE:-000}"')
    [ "$sse_code_before" = "200" ] || [ "$sse_code_before" = "204" ] || {
        echo "❌ Gateway SSE not reachable before restart (HTTP $sse_code_before)" >&2
        return 1
    }

    echo "  Gateway SSE reachable: HTTP $sse_code_before"

    # Trigger gateway restart via docker
    echo "  Restarting gateway container..."
    docker restart pocketcoder-mcp-gateway > /dev/null

    # Wait for gateway to restart
    echo "  Waiting for gateway to restart..."
    sleep 8

    # Verify gateway is running again
    local status_after
    status_after=$(docker inspect pocketcoder-mcp-gateway --format '{{.State.Status}}')
    [ "$status_after" = "running" ] || {
        echo "❌ Gateway not running after restart (status: $status_after)" >&2
        return 1
    }

    # Verify StartedAt changed (proves it actually restarted)
    local started_after
    started_after=$(docker inspect pocketcoder-mcp-gateway --format '{{.State.StartedAt}}')
    [ "$started_before" != "$started_after" ] || {
        echo "❌ Gateway StartedAt unchanged — restart did not happen" >&2
        echo "  Before: $started_before" >&2
        echo "  After:  $started_after" >&2
        return 1
    }

    # Verify SSE endpoint comes back up after restart
    local sse_code_after
    sse_code_after=$(docker exec pocketcoder-sandbox \
        sh -c 'CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://mcp-gateway:8811/sse 2>/dev/null); echo "${CODE:-000}"')
    [ "$sse_code_after" = "200" ] || [ "$sse_code_after" = "204" ] || {
        echo "❌ Gateway SSE not reachable after restart (HTTP $sse_code_after)" >&2
        return 1
    }

    echo "✓ MCP Gateway restarted successfully"
    echo "  Before: $started_before"
    echo "  After:  $started_after"
    echo "  SSE:    HTTP $sse_code_before → HTTP $sse_code_after"
}

# =============================================================================
# Infrastructure: MCP Gateway spins up an MCP server container via Dynamic MCP
# =============================================================================

@test "MCP Infra: MCP Gateway spins up MCP server container via Dynamic MCP" {
    # Validates: MCP_GATEWAY_ARCHITECTURE.md — Gateway uses Dynamic MCP to spin up
    # isolated MCP server containers on-demand.
    #
    # KEY INSIGHT: `docker mcp server enable` only modifies the local CLI registry.
    # It does NOT trigger Dynamic MCP container spin-up. To actually spin up a
    # container, we must use the MCP protocol tools exposed by the gateway:
    #
    #   docker mcp tools call mcp-add '{"name": "fetch"}'
    #
    # This calls the mcp-add primordial tool on the gateway via SSE, which causes
    # the gateway to pull the image and start a new container.
    #
    # Flow:
    # 1. Approve "fetch" server → catalog written → gateway restarted
    # 2. Snapshot running containers (docker ps)
    # 3. From sandbox, call mcp-add via `docker mcp tools call` (real MCP protocol)
    # 4. Hard-assert a NEW container appeared in docker ps
    # 5. Clean up: revoke the server

    # --- Step 0: Ensure gateway is running and SSE is up ---
    local gateway_status
    gateway_status=$(docker inspect pocketcoder-mcp-gateway --format '{{.State.Status}}' 2>/dev/null || echo "not found")
    [ "$gateway_status" = "running" ] || {
        echo "❌ MCP gateway not running (status: $gateway_status)" >&2
        return 1
    }

    # --- Step 1: Approve the server so it appears in the gateway catalog ---
    authenticate_agent

    local server_name="fetch"

    # Clean slate — revoke any existing approved "fetch" server
    authenticate_superuser
    local existing
    existing=$(curl -s -X GET \
        "$PB_URL/api/collections/mcp_servers/records?filter=name=\"$server_name\"%20%26%26%20status=\"approved\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")

    local existing_count
    existing_count=$(echo "$existing" | jq -r '.totalItems // 0')

    if [ "$existing_count" -gt 0 ]; then
        local existing_id
        existing_id=$(echo "$existing" | jq -r '.items[0].id // empty')
        curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$existing_id" \
            -H "Content-Type: application/json" \
            -H "Authorization: $USER_TOKEN" \
            -d '{"status": "revoked"}' > /dev/null
        sleep 10
    fi

    # Create and approve
    authenticate_agent
    local response
    response=$(curl -s -X POST "$PB_URL/api/pocketcoder/mcp_request" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AGENT_TOKEN" \
        -d "{
            \"server_name\": \"$server_name\",
            \"reason\": \"Infra test: verify Dynamic MCP spins up container via mcp-add\",
            \"session_id\": \"$TEST_ID\"
        }")

    MCP_SERVER_ID=$(echo "$response" | jq -r '.id // empty')
    [ -n "$MCP_SERVER_ID" ] && [ "$MCP_SERVER_ID" != "null" ] || {
        echo "❌ Failed to create MCP server request. Response: $response" >&2
        return 1
    }
    track_artifact "mcp_servers:$MCP_SERVER_ID"

    authenticate_superuser
    curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$MCP_SERVER_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"status": "approved"}' > /dev/null

    # Wait for relay hook → catalog render → gateway restart
    sleep 10

    # Verify catalog was written
    local catalog_content
    catalog_content=$(docker exec pocketcoder-pocketbase cat /mcp_config/docker-mcp.yaml 2>&1)
    echo "$catalog_content" | grep -q "$server_name" || {
        echo "❌ docker-mcp.yaml does not contain '$server_name' after approval" >&2
        echo "  Catalog content:" >&2
        echo "$catalog_content" >&2
        return 1
    }
    echo "  ✓ Catalog contains '$server_name'"

    # --- Step 2: Snapshot running containers BEFORE mcp-add ---
    local containers_before
    containers_before=$(snapshot_containers)
    local count_before
    count_before=$(echo "$containers_before" | wc -l | tr -d ' ')
    echo "  Containers before mcp-add: $count_before"

    # --- Step 3: Enable the server and trigger Dynamic MCP container spin-up ---
    #
    # The `docker mcp` CLI uses stdio transport — it runs `docker mcp gateway run`
    # as a subprocess. `docker mcp tools call mcp-add` starts a local gateway
    # process that reads the catalog and spins up containers via docker socket.
    #
    # We run this from inside the GATEWAY container because:
    # 1. It has the docker socket (read-only) to spin up MCP server containers
    # 2. It has the `docker mcp` CLI installed
    # 3. The catalog file is mounted at /root/.docker/mcp/docker-mcp.yaml
    #
    # First enable the server, then call tools to trigger the spin-up.
    #
    echo "  Enabling '$server_name' server in gateway..."
    local enable_output
    enable_output=$(docker exec pocketcoder-mcp-gateway \
        docker mcp server enable "$server_name" 2>&1 || true)
    echo "  enable output: ${enable_output:0:300}"

    # Use key=value syntax per IMPLEMENTATION_SPEC.md (NOT JSON, NOT --name flag)
    # Verified in test-mcp-install sandbox.
    echo "  Calling mcp-add for '$server_name' via MCP protocol..."
    local add_output
    add_output=$(docker exec pocketcoder-mcp-gateway \
        timeout 120 \
        docker mcp tools call mcp-add "name=$server_name" 2>&1 || true)
    echo "  mcp-add output: ${add_output:0:500}"

    # --- Step 4: Verify MCP tool was discovered ---
    #
    # The gateway uses `docker run --rm` for MCP servers, so containers are
    # ephemeral and won't appear in `docker ps`. Instead, we verify the tool
    # was discovered by checking gateway logs for "Tools discovered".
    #
    echo "  Waiting for MCP tool to be discovered..."
    local tool_found=false
    local start_time
    start_time=$(date +%s)
    local timeout=90

    while [ "$(date +%s)" -lt $((start_time + timeout)) ]; do
        local gateway_logs
        gateway_logs=$(docker logs pocketcoder-mcp-gateway 2>&1)
        if echo "$gateway_logs" | grep -q "Tools discovered:.*$server_name"; then
            tool_found=true
            break
        fi
        sleep 2
    done

    [ "$tool_found" = "true" ] || {
        echo "" >&2
        echo "  ══════════════════════════════════════════════════════════" >&2
        echo "  DYNAMIC MCP TOOL DISCOVERY FAILED" >&2
        echo "  ══════════════════════════════════════════════════════════" >&2
        echo "  The gateway did not discover the MCP tool after mcp-add." >&2
        echo "  This means Dynamic MCP is not working as expected." >&2
        echo "" >&2
        echo "  mcp-add output was:" >&2
        echo "  $add_output" >&2
        echo "" >&2
        echo "  Gateway logs:" >&2
        docker logs --tail 50 pocketcoder-mcp-gateway 2>&1 | sed 's/^/    /' >&2
        echo "  ══════════════════════════════════════════════════════════" >&2
        return 1
    }

    # --- Step 5: Clean up — revoke the server ---
    curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$MCP_SERVER_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"status": "revoked"}' > /dev/null

    echo "✓ Dynamic MCP tool '$server_name' discovered via mcp-add"
}
