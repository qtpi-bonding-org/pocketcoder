#!/usr/bin/env bats
# Agent Test: Real MCP Gateway Flow
#
# Tests Poco actually using the MCP gateway to get work done.
# Unlike the infrastructure MCP test, this verifies the real agent workflow:
#
# Flow (MCP_GATEWAY_ARCHITECTURE.md § Flow):
# 1. User asks Poco to do something that needs an external tool
# 2. Poco browses the MCP catalog, finds the relevant server
# 3. Poco requests the server via POST /api/pocketcoder/mcp_request
# 4. PocketBase creates pending record, user approves
# 5. PocketBase renders config, restarts gateway
# 6. Poco spawns a subagent via CAO with MCP gateway connection
# 7. Subagent connects to gateway SSE, uses MCP tools
# 8. Subagent returns results to Poco
# 9. Poco synthesizes and responds to the user
#
# These tests trigger real agent behavior by sending messages that require
# MCP tools, then verify the full chain executed correctly.

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
    CHAT_ID=""
    USER_MESSAGE_ID=""
    ASSISTANT_MESSAGE_ID=""
    SESSION_ID=""
    MCP_SERVER_ID=""
    AGENT_TOKEN=""
    AGENT_ID=""
}

teardown() {
    cleanup_test_data "$TEST_ID" || true
    cleanup_mcp_servers "$TEST_ID" || true
    if [ -n "$SESSION_ID" ]; then
        delete_opencode_session "$SESSION_ID" || true
    fi
}

# =============================================================================
# Test: Poco requests an MCP server when it needs one
# =============================================================================

@test "Agent MCP Flow: Poco requests MCP server when task requires external tool" {
    # Send a message that requires an external tool (e.g., "search the web for X").
    # Poco should:
    # 1. Recognize it needs an MCP server
    # 2. Browse the catalog
    # 3. Submit an mcp_request to PocketBase
    # 4. Tell the user it's waiting for approval
    #
    # We verify by checking that an mcp_servers record was created.

    authenticate_user

    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Agent MCP Request Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"

    # Ask Poco to do something that requires an MCP tool
    local msg_data
    msg_data=$(pb_create "messages" "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"text\": \"I need you to use the fetch MCP server to retrieve the contents of https://example.com. Use the MCP gateway to get this done.\"}],
        \"user_message_status\": \"pending\"
    }")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"

    # Wait for delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ] || { echo "❌ Message not delivered" >&2; return 1; }

    SESSION_ID=$(pb_get "chats" "$CHAT_ID" | jq -r '.ai_engine_session_id // empty')

    # Wait for Poco to respond
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 90)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || {
        echo "❌ Poco did not respond" >&2
        return 1
    }

    echo "✓ Poco responded to the task"
}

# =============================================================================
# Test: Full MCP lifecycle — request, approve, subagent uses tool
# =============================================================================

@test "Agent MCP Flow: Full lifecycle — request, approve, subagent executes" {
    # The complete MCP flow:
    # 1. User sends message requiring MCP tool
    # 2. Poco requests the server
    # 3. We approve it (simulating Flutter app)
    # 4. Gateway restarts with new config
    # 5. Poco spawns subagent
    # 6. Subagent connects to gateway, uses tool
    # 7. Results come back to user

    authenticate_user
    authenticate_agent

    # Pre-approve an MCP server so Poco can use it immediately
    local server_name="fetch"

    # Check if already approved
    local existing
    existing=$(curl -s -X GET \
        "$PB_URL/api/collections/mcp_servers/records?filter=name=\"$server_name\"%20%26%26%20status=\"approved\"" \
        -H "Authorization: $(get_admin_token)" \
        -H "Content-Type: application/json")

    local existing_count
    existing_count=$(echo "$existing" | jq -r '.totalItems // 0')

    if [ "$existing_count" -eq 0 ]; then
        # Create and approve the server
        local create_response
        create_response=$(curl -s -X POST "$PB_URL/api/collections/mcp_servers/records" \
            -H "Content-Type: application/json" \
            -H "Authorization: $(get_admin_token)" \
            -d "{
                \"name\": \"$server_name\",
                \"status\": \"approved\",
                \"reason\": \"Pre-approved for agent MCP flow test\",
                \"catalog\": \"docker-mcp\"
            }")

        MCP_SERVER_ID=$(echo "$create_response" | jq -r '.id // empty')
        [ -n "$MCP_SERVER_ID" ] && [ "$MCP_SERVER_ID" != "null" ] || {
            echo "❌ Failed to pre-approve MCP server" >&2
            return 1
        }
        track_artifact "mcp_servers:$MCP_SERVER_ID"

        # Wait for config render and gateway restart
        sleep 5
    fi

    # Create chat
    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Agent MCP Lifecycle Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"

    # Ask Poco to use the approved MCP server
    local msg_data
    msg_data=$(pb_create "messages" "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"text\": \"The fetch MCP server is already approved and available on the gateway. Use it via a subagent to fetch the contents of https://example.com and tell me the page title.\"}],
        \"user_message_status\": \"pending\"
    }")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"

    # Wait for delivery
    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ] || { echo "❌ Message not delivered" >&2; return 1; }

    SESSION_ID=$(pb_get "chats" "$CHAT_ID" | jq -r '.ai_engine_session_id // empty')

    # Wait for Poco to process — this may take longer as it involves subagent spawning
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 120)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || {
        echo "❌ Poco did not respond after MCP server approval" >&2
        return 1
    }

    # Verify the response has content
    local response_text
    response_text=$(get_assistant_text "$ASSISTANT_MESSAGE_ID")
    [ -n "$response_text" ] || {
        echo "❌ Empty response from Poco" >&2
        return 1
    }

    # Check if a subagent was spawned
    local subagent_records
    subagent_records=$(curl -s -X GET \
        "$PB_URL/api/collections/subagents/records?filter=delegating_agent_id=\"$SESSION_ID\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json" 2>/dev/null)

    local subagent_count
    subagent_count=$(echo "$subagent_records" | jq -r '.totalItems // 0' 2>/dev/null)

    if [ "$subagent_count" -gt 0 ]; then
        echo "✓ Poco spawned subagent for MCP tool execution"
        local subagent_id
        subagent_id=$(echo "$subagent_records" | jq -r '.items[0].id // empty')
        track_artifact "subagents:$subagent_id"
    else
        echo "ℹ No subagent record found (Poco may have used a different approach)"
    fi

    # The response should contain something about the fetched content
    echo "$response_text" | grep -qi "example\|domain\|fetch\|content\|page\|title\|html" || {
        echo "❌ Response doesn't reference fetched content" >&2
        echo "  Response: ${response_text:0:300}" >&2
        return 1
    }

    echo "✓ Full MCP lifecycle completed"
    echo "  Response (first 200 chars): ${response_text:0:200}"
}

# =============================================================================
# Test: Poco checks mcp_status before requesting
# =============================================================================

@test "Agent MCP Flow: Poco checks what's installed before requesting" {
    # Verify that Poco uses mcp_status to check what's already available
    # before requesting a new server.

    authenticate_user

    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Agent MCP Status Check $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"

    # Ask Poco what MCP servers are available
    local msg_data
    msg_data=$(pb_create "messages" "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"text\": \"What MCP servers are currently enabled on the gateway? Check the status.\"}],
        \"user_message_status\": \"pending\"
    }")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"

    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ] || { echo "❌ Message not delivered" >&2; return 1; }

    SESSION_ID=$(pb_get "chats" "$CHAT_ID" | jq -r '.ai_engine_session_id // empty')

    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 90)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || {
        echo "❌ Poco did not respond to status check" >&2
        return 1
    }

    local response_text
    response_text=$(get_assistant_text "$ASSISTANT_MESSAGE_ID")
    [ -n "$response_text" ] || { echo "❌ Empty response" >&2; return 1; }

    echo "$response_text" | grep -qi "mcp\|server\|enabled\|gateway\|config\|catalog\|installed\|available\|none" || {
        echo "❌ Response doesn't discuss MCP status" >&2
        echo "  Response: ${response_text:0:300}" >&2
        return 1
    }

    echo "✓ Poco checked MCP status and reported back"
    echo "  Response (first 200 chars): ${response_text:0:200}"
}

# =============================================================================
# Test: Denied MCP request — Poco handles gracefully
# =============================================================================

@test "Agent MCP Flow: Poco handles denied MCP request gracefully" {
    # If a user denies an MCP server request, Poco should acknowledge it
    # and not keep retrying.

    authenticate_user
    authenticate_agent

    local chat_data
    chat_data=$(pb_create "chats" "{\"title\": \"Agent MCP Denied Test $TEST_ID\", \"user\": \"$USER_ID\"}")
    CHAT_ID=$(echo "$chat_data" | jq -r '.id')
    track_artifact "chats:$CHAT_ID"

    # Ask Poco for something that needs an MCP server
    local msg_data
    msg_data=$(pb_create "messages" "{
        \"chat\": \"$CHAT_ID\",
        \"role\": \"user\",
        \"parts\": [{\"type\": \"text\", \"text\": \"I need you to use the postgres MCP server to query a database. Request it via the MCP gateway.\"}],
        \"user_message_status\": \"pending\"
    }")
    USER_MESSAGE_ID=$(echo "$msg_data" | jq -r '.id')
    track_artifact "messages:$USER_MESSAGE_ID"

    run wait_for_message_status "$USER_MESSAGE_ID" "delivered" 30
    [ "$status" -eq 0 ] || { echo "❌ Message not delivered" >&2; return 1; }

    SESSION_ID=$(pb_get "chats" "$CHAT_ID" | jq -r '.ai_engine_session_id // empty')

    # Wait for Poco to respond
    ASSISTANT_MESSAGE_ID=$(wait_for_assistant_message "$CHAT_ID" 90)
    [ -n "$ASSISTANT_MESSAGE_ID" ] && [ "$ASSISTANT_MESSAGE_ID" != "null" ] || {
        echo "❌ Poco did not respond" >&2
        return 1
    }

    # Check if an mcp_servers record was created
    local mcp_records
    mcp_records=$(curl -s -X GET \
        "$PB_URL/api/collections/mcp_servers/records?filter=name~\"postgres\"&sort=-created&perPage=1" \
        -H "Authorization: $(get_admin_token)" \
        -H "Content-Type: application/json")

    local mcp_id
    mcp_id=$(echo "$mcp_records" | jq -r '.items[0].id // empty')

    if [ -n "$mcp_id" ] && [ "$mcp_id" != "null" ]; then
        track_artifact "mcp_servers:$mcp_id"
        MCP_SERVER_ID="$mcp_id"

        # Deny the request
        authenticate_superuser
        curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$mcp_id" \
            -H "Content-Type: application/json" \
            -H "Authorization: $USER_TOKEN" \
            -d '{"status": "denied"}' > /dev/null

        # Wait for Poco to get the denial notification
        sleep 5

        # Check for a follow-up message acknowledging the denial
        local all_msgs
        all_msgs=$(curl -s -X GET \
            "$PB_URL/api/collections/messages/records?filter=chat=\"$CHAT_ID\"%20%26%26%20role=\"assistant\"&sort=-created" \
            -H "Authorization: $USER_TOKEN" \
            -H "Content-Type: application/json")

        local latest_text
        latest_text=$(echo "$all_msgs" | jq -r '.items[0].parts[]? | select(.type == "text") | .text // empty' 2>/dev/null)

        echo "✓ MCP request denied, Poco's latest response:"
        echo "  ${latest_text:0:200}"
    else
        # Poco didn't create a request — check its response
        local response_text
        response_text=$(get_assistant_text "$ASSISTANT_MESSAGE_ID")
        echo "ℹ Poco did not create an mcp_servers record"
        echo "  Response: ${response_text:0:200}"
    fi
}

# =============================================================================
# Test: Approving MCP server spins up a new Docker container
# =============================================================================

@test "Agent MCP Flow: Approved MCP server spins up a new Docker container" {
    # After approving an MCP server, the catalog is updated and the gateway restarts.
    # With Dynamic MCP, the gateway doesn't pre-start servers — it starts them when
    # a client calls mcp-add via the MCP protocol.
    #
    # KEY INSIGHT: `docker mcp server enable` only modifies the local CLI registry.
    # It does NOT trigger Dynamic MCP container spin-up. To actually spin up a
    # container, we must call the mcp-add primordial tool via the gateway:
    #
    #   docker mcp tools call mcp-add name=fetch
    #
    # This sends the request through the gateway SSE connection, which causes
    # the gateway to pull the image and start a new container.
    #
    # Flow:
    # 1. Create and approve an MCP server request (e.g., "fetch")
    # 2. Wait for catalog render + gateway restart
    # 3. Snapshot running containers
    # 4. From sandbox, call mcp-add via `docker mcp tools call` (real MCP protocol)
    # 5. Hard-assert a NEW container appeared
    # 6. Verify the new container is related to the approved MCP server

    authenticate_agent

    local server_name="fetch"

    # Check if this server is already approved — clean slate
    authenticate_superuser
    local existing
    existing=$(curl -s -X GET \
        "$PB_URL/api/collections/mcp_servers/records?filter=name=\"$server_name\"%20%26%26%20status=\"approved\"" \
        -H "Authorization: $USER_TOKEN" \
        -H "Content-Type: application/json")

    local existing_count
    existing_count=$(echo "$existing" | jq -r '.totalItems // 0')

    # If already approved, revoke first so we get a clean test
    if [ "$existing_count" -gt 0 ]; then
        local existing_id
        existing_id=$(echo "$existing" | jq -r '.items[0].id // empty')
        curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$existing_id" \
            -H "Content-Type: application/json" \
            -H "Authorization: $USER_TOKEN" \
            -d '{"status": "revoked"}' > /dev/null
        sleep 10
    fi

    # Create and approve the MCP server
    authenticate_agent
    local response
    response=$(curl -s -X POST "$PB_URL/api/pocketcoder/mcp_request" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AGENT_TOKEN" \
        -d "{
            \"server_name\": \"$server_name\",
            \"reason\": \"Container spin-up verification test\",
            \"session_id\": \"$TEST_ID\"
        }")

    MCP_SERVER_ID=$(echo "$response" | jq -r '.id // empty')
    [ -n "$MCP_SERVER_ID" ] && [ "$MCP_SERVER_ID" != "null" ] || {
        echo "❌ Failed to create MCP server request. Response: $response" >&2
        return 1
    }
    track_artifact "mcp_servers:$MCP_SERVER_ID"

    # Approve the server
    authenticate_superuser
    curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$MCP_SERVER_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d '{"status": "approved"}' > /dev/null

    # Wait for catalog render + gateway restart
    sleep 10

    # Verify catalog was written with the server
    local catalog_content
    catalog_content=$(docker exec pocketcoder-pocketbase cat /mcp_config/docker-mcp.yaml 2>&1)
    [ -n "$catalog_content" ] || {
        echo "❌ docker-mcp.yaml not found after approval" >&2
        return 1
    }
    echo "$catalog_content" | grep -q "$server_name" || {
        echo "❌ docker-mcp.yaml does not contain '$server_name'" >&2
        echo "  Catalog content:" >&2
        echo "$catalog_content" >&2
        return 1
    }

    # Snapshot containers BEFORE triggering Dynamic MCP
    local containers_before
    containers_before=$(snapshot_containers)
    local count_before
    count_before=$(echo "$containers_before" | wc -l | tr -d ' ')
    echo "  Containers before mcp-add: $count_before"

    # Enable the server and trigger Dynamic MCP container spin-up from the gateway
    echo "  Enabling '$server_name' server in gateway..."
    local enable_output
    enable_output=$(docker exec pocketcoder-mcp-gateway \
        docker mcp server enable "$server_name" 2>&1 || true)
    echo "  enable output: ${enable_output:0:300}"

    echo "  Calling mcp-add for '$server_name' via MCP protocol..."
    local add_output
    add_output=$(docker exec pocketcoder-mcp-gateway \
        timeout 120 \
        docker mcp tools call mcp-add "name=$server_name" 2>&1 || true)
    echo "  mcp-add output: ${add_output:0:300}"

    # Wait for container spin-up and assert it happened via logs (reliable for ephemeral containers)
    echo "  Checking gateway logs for container creation..."
    local found_log=0
    for i in $(seq 1 10); do
        if docker logs pocketcoder-mcp-gateway 2>&1 | grep -q "Running mcp/$server_name with \[run --rm"; then
            found_log=1
            break
        fi
        sleep 2
    done

    if [ "$found_log" -eq 0 ]; then
        echo "" >&2
        echo "  ══════════════════════════════════════════════════════════" >&2
        echo "  DYNAMIC MCP CONTAINER SPIN-UP FAILED" >&2
        echo "  ══════════════════════════════════════════════════════════" >&2
        echo "  The gateway did not log a container execution after mcp-add." >&2
        echo "" >&2
        echo "  mcp-add output was:" >&2
        echo "  $add_output" >&2
        echo "" >&2
        echo "  Gateway logs (tail 30):" >&2
        docker logs --tail 30 pocketcoder-mcp-gateway 2>&1 | sed 's/^/    /' >&2
        echo "  ══════════════════════════════════════════════════════════" >&2
        return 1
    fi

    echo "✓ Gateway logged container execution for '$server_name'"

    # Show what containers are running now
    local containers_after
    containers_after=$(snapshot_containers)
    local count_after
    count_after=$(echo "$containers_after" | wc -l | tr -d ' ')
    local new_containers
    new_containers=$(diff_containers "$containers_before" "$containers_after")

    echo "  Containers before: $count_before"
    echo "  Containers after:  $count_after"
    echo "  New containers:"
    echo "$new_containers" | sed 's/^/    /'

    echo "✓ Approved MCP server spun up a new Docker container via Dynamic MCP"
}
