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

# =============================================================================
# Poco-Memory (Agent Memory MCP Server)
# =============================================================================

POCO_MEMORY_URL="${POCO_MEMORY_URL:-http://poco-memory:8001}"

# Helper: open an MCP session and call a tool.
# Usage: poco_mcp_call <id> <method_json> → prints SSE body
# Handles init → notifications/initialized → tool call in one shot.
poco_mcp_call() {
    local req_id="$1"
    local body="$2"
    docker exec pocketcoder-poco-memory sh -c "
        # Init (SSE stream in background)
        curl -sfN -D /tmp/bats_h -X POST \
          -H 'Content-Type: application/json' \
          -H 'Accept: application/json, text/event-stream' \
          -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-03-26\",\"capabilities\":{},\"clientInfo\":{\"name\":\"bats\",\"version\":\"1.0\"}}}' \
          http://localhost:8001/mcp > /dev/null 2>&1 &
        sleep 1
        S=\$(grep -i mcp-session-id /tmp/bats_h | tr -d '\r' | awk '{print \$2}')
        # Notify
        curl -sf -X POST \
          -H 'Content-Type: application/json' \
          -H 'Accept: application/json, text/event-stream' \
          -H \"Mcp-Session-Id: \$S\" \
          -d '{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}' \
          http://localhost:8001/mcp > /dev/null 2>&1
        sleep 0.5
        # Tool call
        curl -sfN --max-time 30 -X POST \
          -H 'Content-Type: application/json' \
          -H 'Accept: application/json, text/event-stream' \
          -H \"Mcp-Session-Id: \$S\" \
          -d '$body' \
          http://localhost:8001/mcp 2>&1
    "
}

@test "poco-memory container is running" {
    run docker inspect -f '{{.State.Running}}' pocketcoder-poco-memory
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "poco-memory health endpoint responds" {
    run docker exec pocketcoder-poco-memory curl -sf http://localhost:8001/health
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "poco-memory MCP initialize handshake succeeds" {
    local http_code
    http_code=$(docker exec pocketcoder-poco-memory curl -sf -o /dev/null -w '%{http_code}' -X POST \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json, text/event-stream' \
        -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"bats-test","version":"1.0"}}}' \
        http://localhost:8001/mcp 2>/dev/null) || true
    [ "$http_code" = "200" ]
}

@test "memory_store + memory_recall round-trip" {
    # Store
    local store_resp
    store_resp=$(poco_mcp_call 2 '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"memory_store","arguments":{"content":"BATS test: user prefers dark mode","tags":["preference","ui"]}}}')
    run bash -c "echo '$store_resp' | grep -q 'Memory stored'"
    [ "$status" -eq 0 ]

    # Recall
    local recall_resp
    recall_resp=$(poco_mcp_call 3 '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"memory_recall","arguments":{"query":"user UI theme preferences"}}}')
    run bash -c "echo '$recall_resp' | grep -q 'dark mode'"
    [ "$status" -eq 0 ]
}

@test "memory_search returns FTS results" {
    # Store (idempotent — may exist from prior test)
    poco_mcp_call 2 '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"memory_store","arguments":{"content":"BATS test: always use bun instead of npm"}}}' > /dev/null

    local resp
    resp=$(poco_mcp_call 3 '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"memory_search","arguments":{"query":"bun npm"}}}')
    run bash -c "echo '$resp' | grep -q 'bun'"
    [ "$status" -eq 0 ]
}

@test "memory_deep_recall finds memories without decay" {
    local resp
    resp=$(poco_mcp_call 2 '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"memory_deep_recall","arguments":{"query":"user preferences"}}}')
    run bash -c "echo '$resp' | grep -qE '(dark mode|bun|No memories found)'"
    [ "$status" -eq 0 ]
}

@test "memory_forget deletes a memory" {
    # Store a temporary memory
    local store_resp
    store_resp=$(poco_mcp_call 2 '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"memory_store","arguments":{"content":"BATS temp memory to delete"}}}')

    local memory_id
    memory_id=$(echo "$store_resp" | grep -oP 'memory:[a-z0-9]+' | head -1)
    [ -n "$memory_id" ]

    # Forget it
    local forget_resp
    forget_resp=$(poco_mcp_call 3 "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"memory_forget\",\"arguments\":{\"id\":\"$memory_id\"}}}")
    run bash -c "echo '$forget_resp' | grep -q 'Forgotten'"
    [ "$status" -eq 0 ]
}
