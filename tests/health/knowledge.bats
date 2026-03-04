#!/usr/bin/env bats
# Health tests for the knowledge stack (--profile knowledge)
#
# Validates: surrealdb, open-notebook, open-notebook-mcp, poco-memory

load '../helpers/auth.sh'
load '../helpers/wait.sh'
load '../helpers/tracking.sh'

setup() {
    load_env
}

# =============================================================================
# SurrealDB
# =============================================================================

@test "surrealdb container is running" {
    run docker inspect -f '{{.State.Running}}' pocketcoder-surrealdb
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "surrealdb health responds inside container" {
    run docker exec pocketcoder-surrealdb curl -sf http://localhost:8000/health
    [ "$status" -eq 0 ]
}

@test "surrealdb has no exposed host ports" {
    local ports
    ports=$(docker inspect -f '{{json .NetworkSettings.Ports}}' pocketcoder-surrealdb)
    run bash -c "echo '$ports' | grep -q 'HostPort'"
    [ "$status" -ne 0 ]
}

# =============================================================================
# OpenNotebook
# =============================================================================

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
# Poco-Memory
# =============================================================================

@test "poco-memory container is running" {
    run docker inspect -f '{{.State.Running}}' pocketcoder-poco-memory
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "poco-memory health endpoint returns ok" {
    run docker exec pocketcoder-poco-memory curl -sf http://localhost:8001/health
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "poco-memory health check completes within 30 seconds" {
    run timeout 30 docker exec pocketcoder-poco-memory curl -sf http://localhost:8001/health
    [ "$status" -eq 0 ]
}

@test "poco-memory docker healthcheck reports healthy" {
    run docker inspect -f '{{.State.Health.Status}}' pocketcoder-poco-memory
    [ "$status" -eq 0 ]
    [ "$output" = "healthy" ]
}

@test "poco-memory MCP endpoint accepts initialize" {
    local http_code
    http_code=$(docker exec pocketcoder-poco-memory curl -sf -o /dev/null -w '%{http_code}' -X POST \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json, text/event-stream' \
        -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"bats-health","version":"1.0"}}}' \
        http://localhost:8001/mcp 2>/dev/null) || true
    [ "$http_code" = "200" ]
}
