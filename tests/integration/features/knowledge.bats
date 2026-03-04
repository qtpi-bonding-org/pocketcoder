#!/usr/bin/env bats
# Feature: Knowledge Base (OpenNotebook + SurrealDB)
#
# Integration tests for the knowledge stack (--profile knowledge).
#
# Tests:
# 1. SurrealDB container is running
# 2. OpenNotebook container is running
# 3. OpenNotebook MCP container is running
# 4. SurrealDB is not reachable from host (no exposed ports)
# 5. SurrealDB is reachable from OpenNotebook on knowledge network
# 6. OpenNotebook REST API health (GET /docs returns 200)
# 7. OpenNotebook UI health (via docker exec, frontend binds to localhost)
# 8. MCP endpoint is reachable on knowledge network
# 9. OpenNotebook API CRUD (create notebook, list notebooks)

load '../../helpers/auth.sh'
load '../../helpers/wait.sh'
load '../../helpers/tracking.sh'

# --- URLs (Docker service names — test container is on knowledge network) ---
NOTEBOOK_API_URL="${NOTEBOOK_API_URL:-http://open-notebook:5055}"

setup() {
    load_env
}

# =============================================================================
# Container Health
# =============================================================================

@test "surrealdb container is running" {
    run docker inspect -f '{{.State.Running}}' pocketcoder-surrealdb
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "open-notebook container is running" {
    run docker inspect -f '{{.State.Running}}' pocketcoder-open-notebook
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "open-notebook-mcp container is running" {
    run docker inspect -f '{{.State.Running}}' pocketcoder-open-notebook-mcp
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

# =============================================================================
# Network Isolation
# =============================================================================

@test "surrealdb is NOT reachable from host (no exposed ports)" {
    # SurrealDB should not have any port bindings
    local ports
    ports=$(docker inspect -f '{{json .NetworkSettings.Ports}}' pocketcoder-surrealdb)
    # Should either be empty, null, or have no host bindings
    run bash -c "echo '$ports' | grep -q 'HostPort'"
    [ "$status" -ne 0 ]
}

@test "surrealdb is reachable from open-notebook on knowledge network" {
    run docker exec pocketcoder-open-notebook bash -c \
        "curl -sf http://surrealdb:8000/health 2>/dev/null || python3 -c \"import urllib.request; urllib.request.urlopen('http://surrealdb:8000/health')\" 2>/dev/null"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Endpoint Health
# =============================================================================

@test "opennotebook REST API is reachable (/docs)" {
    wait_for_endpoint "$NOTEBOOK_API_URL/docs" 60
}

@test "opennotebook UI is reachable (:8502)" {
    # The Next.js frontend binds to localhost inside the container,
    # so we test via docker exec rather than cross-container HTTP
    run docker exec pocketcoder-open-notebook bash -c \
        "curl -sf -o /dev/null -w '%{http_code}' http://localhost:8502 2>/dev/null"
    [[ "$output" =~ ^(200|307)$ ]]
}

@test "opennotebook MCP endpoint is reachable on knowledge network" {
    local http_code
    http_code=$(curl -sf -o /dev/null -w '%{http_code}' -X POST \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json, text/event-stream' \
        -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"bats-test","version":"1.0"}}}' \
        http://open-notebook-mcp:8000/mcp 2>/dev/null) || true
    [ "$http_code" = "200" ]
}

# =============================================================================
# OpenNotebook API CRUD
# =============================================================================

@test "can create and list notebooks via REST API" {
    # Create a notebook
    local create_response
    create_response=$(curl -sf -X POST "$NOTEBOOK_API_URL/api/notebooks" \
        -H "Content-Type: application/json" \
        -d '{"name": "BATS Test Notebook"}')
    local notebook_id
    notebook_id=$(echo "$create_response" | jq -r '.id // empty')
    [ -n "$notebook_id" ]

    # List notebooks — the created one should appear
    local list_response
    list_response=$(curl -sf "$NOTEBOOK_API_URL/api/notebooks")
    run bash -c "echo '$list_response' | jq -e '.[] | select(.name == \"BATS Test Notebook\")'"
    [ "$status" -eq 0 ]

    # Cleanup
    curl -sf -X DELETE "$NOTEBOOK_API_URL/api/notebooks/$notebook_id" > /dev/null 2>&1 || true
}
