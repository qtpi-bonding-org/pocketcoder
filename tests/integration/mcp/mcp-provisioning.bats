#!/usr/bin/env bats
# Feature: mcp-provisioning, Autonomous Provisioning Integration Test

load '../../helpers/auth.sh'
load '../../helpers/cleanup.sh'
load '../../helpers/wait.sh'
load '../../helpers/assertions.sh'
load '../../helpers/tracking.sh'
load '../../helpers/mcp.sh'

setup() {
    load_env
    TEST_ID=$(generate_test_id)
    export CURRENT_TEST_ID="$TEST_ID"
    # We use a real server name from the default catalog if possible, 
    # but for testing the RELAY it doesn't matter if the image exists 
    # as long as we don't try to SPIN it up.
    SERVER_NAME="n8n" 
}

teardown() {
    cleanup_mcp_servers "$TEST_ID" || true
}

@test "MCP Provisioning: mcp.env is generated with secrets after approval" {
    # Validates: Requirement 9.1 & 10.1 — Secrets from PB injected into mcp.env

    authenticate_agent

    # 1. Create request via API
    local response
    response=$(curl -s -X POST "$PB_URL/api/pocketcoder/mcp_request" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AGENT_TOKEN" \
        -d "{
            \"server_name\": \"secrets-$SERVER_NAME-$TEST_ID\",
            \"reason\": \"Secret injection test\",
            \"session_id\": \"$TEST_ID\",
            \"image\": \"mcp/n8n-test:latest\",
            \"config_schema\": {\"N8N_API_KEY\": \"The API Key\", \"N8N_API_URL\": \"The URL\"}
        }")

    local id=$(echo "$response" | jq -r '.id // empty')
    [ -n "$id" ] || { echo "❌ Failed to create request: $response" >&2; return 1; }

    # 2. Approve with secrets in 'config' field (simulating user providing secrets in UI)
    authenticate_superuser
    curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$id" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d "{
            \"status\": \"approved\",
            \"config\": {
                \"N8N_API_KEY\": \"test-key-pwnd-123\",
                \"N8N_API_URL\": \"http://n8n.local:5678\"
            }
        }" > /dev/null

    # Wait for Relay hook → config render
    sleep 5

    # 3. Verify mcp.env in PB container (where Relay runs)
    local mcp_env
    mcp_env=$(docker exec pocketcoder-pocketbase cat /mcp_config/mcp.env 2>&1)
    
    echo "$mcp_env" | grep -q "N8N_API_KEY" || {
        echo "❌ mcp.env missing N8N_API_KEY. Content:" >&2
        echo "$mcp_env" >&2
        return 1
    }
    echo "$mcp_env" | grep -q "test-key-pwnd-123" || {
        echo "❌ mcp.env missing secret value. Content:" >&2
        echo "$mcp_env" >&2
        return 1
    }
    echo "$mcp_env" | grep -q "N8N_API_URL" || {
        echo "❌ mcp.env missing N8N_API_URL" >&2
        return 1
    }
    
    echo "✓ mcp.env generated with injected secrets"
}

@test "MCP Provisioning: docker-mcp.yaml uses image from DB" {
    # Validates: Dynamic image names in catalog

    authenticate_agent
    local custom_image="my-registry/custom-mcp:v1.2.3"

    # 1. Create request
    local response
    response=$(curl -s -X POST "$PB_URL/api/pocketcoder/mcp_request" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AGENT_TOKEN" \
        -d "{
            \"server_name\": \"image-$SERVER_NAME-$TEST_ID\",
            \"reason\": \"Image discovery test\",
            \"session_id\": \"$TEST_ID\",
            \"image\": \"$custom_image\"
        }")

    local id=$(echo "$response" | jq -r '.id // empty')

    # 2. Approve
    authenticate_superuser
    curl -s -X PATCH "$PB_URL/api/collections/mcp_servers/records/$id" \
        -H "Content-Type: application/json" \
        -H "Authorization: $USER_TOKEN" \
        -d "{\"status\": \"approved\"}" > /dev/null

    sleep 5

    # 3. Verify docker-mcp.yaml
    local catalog_yaml
    catalog_yaml=$(docker exec pocketcoder-pocketbase cat /mcp_config/docker-mcp.yaml 2>&1)
    
    echo "$catalog_yaml" | grep -q "$custom_image" || {
        echo "❌ docker-mcp.yaml does not contain custom image: $custom_image" >&2
        echo "  Catalog content:" >&2
        echo "$catalog_yaml" >&2
        return 1
    }
    
    echo "✓ docker-mcp.yaml correctly uses image from record"
}
