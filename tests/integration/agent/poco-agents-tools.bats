#!/usr/bin/env bats
# Feature: poco-agents MCP tool introspection
#
# Lightweight tests for poco-agents MCP tools that do NOT require an LLM.
# These are pure read-only / introspection calls — no side effects, no cleanup.
#
# poco-agents runs inside the sandbox container at port 9888, exposing
# a Streamable HTTP MCP endpoint at /mcp.

load '../../helpers/auth.sh'
load '../../helpers/wait.sh'
load '../../helpers/poco-agents.sh'

# --- MCP call helper ---
# Opens an MCP session and calls a method using sequential HTTP requests.
# rmcp (Rust) does NOT support batch JSON-RPC, so we must send individual requests
# and track the session via Mcp-Session-Id header.
# Args:
#   $1 — timeout (seconds)
#   $2 — JSON-RPC payload for the actual request
# Returns: the JSON-RPC response (extracted from SSE data: lines)
poco_agents_mcp_call() {
    local timeout="${1:-10}"
    local payload="$2"
    local mcp_url="http://sandbox:9888/mcp"

    # Step 1: Initialize — capture the session ID from response headers
    local init_headers
    init_headers=$(mktemp)
    curl -sf --max-time "$timeout" -D "$init_headers" -o /dev/null \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"bats","version":"1.0"}}}' \
        "$mcp_url" 2>/dev/null

    local session_id
    session_id=$(grep -i 'mcp-session-id' "$init_headers" | tr -d '\r' | awk '{print $2}')
    rm -f "$init_headers"

    if [ -z "$session_id" ]; then
        echo "ERROR: No session ID from initialize" >&2
        return 1
    fi

    # Step 2: Send notifications/initialized
    curl -sf --max-time "$timeout" -o /dev/null \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -H "Mcp-Session-Id: $session_id" \
        -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
        "$mcp_url" 2>/dev/null

    # Step 3: Send the actual request and extract JSON from SSE
    local raw_response
    raw_response=$(curl -sf --max-time "$timeout" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -H "Mcp-Session-Id: $session_id" \
        -d "$payload" \
        "$mcp_url" 2>/dev/null)

    # Extract JSON from SSE data: lines
    echo "$raw_response" | sed -n 's/^data: //p' | grep -E '^\{' | tail -1
}

setup() {
    load_env
    POCO_AGENTS_URL="${POCO_AGENTS_URL:-http://sandbox:9888}"

    if ! verify_poco_agents_accessible; then
        skip "poco-agents not accessible at $POCO_AGENTS_URL"
    fi
}

# =============================================================================
# MCP Tool Introspection
# =============================================================================

@test "tools/list returns all expected poco-agents tools" {
    local payload='{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
    local response
    response=$(poco_agents_mcp_call 10 "$payload")

    echo "Response: $response"

    # Write to temp file to avoid shell quoting issues with single quotes in JSON
    local tmpfile
    tmpfile=$(mktemp)
    echo "$response" > "$tmpfile"

    # Verify we got a valid JSON-RPC response with tools
    run jq -e '.result.tools' "$tmpfile"
    [ "$status" -eq 0 ]

    # Check each expected tool is present
    local expected_tools=("spawn" "continue_agent" "list_agents" "check_agent" "snapshot" "result" "profiles" "cleanup")
    for tool_name in "${expected_tools[@]}"; do
        run jq -e --arg name "$tool_name" '.result.tools[] | select(.name == $name)' "$tmpfile"
        [ "$status" -eq 0 ]
    done

    rm -f "$tmpfile"
}

@test "list_agents returns an array (empty when no agents running)" {
    local payload='{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"list_agents","arguments":{}}}'
    local response
    response=$(poco_agents_mcp_call 10 "$payload")

    echo "Response: $response"

    local tmpfile
    tmpfile=$(mktemp)
    echo "$response" > "$tmpfile"

    # Should have a result with content
    run jq -e '.result.content[0].text' "$tmpfile"
    [ "$status" -eq 0 ]

    # The text content should be a valid JSON array
    local text
    text=$(jq -r '.result.content[0].text' "$tmpfile")
    rm -f "$tmpfile"

    tmpfile=$(mktemp)
    echo "$text" > "$tmpfile"
    run jq -e 'type == "array"' "$tmpfile"
    rm -f "$tmpfile"
    [ "$status" -eq 0 ]
}

@test "profiles returns available agent profiles" {
    local payload='{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"profiles","arguments":{}}}'
    local response
    response=$(poco_agents_mcp_call 10 "$payload")

    echo "Response: $response"

    local tmpfile
    tmpfile=$(mktemp)
    echo "$response" > "$tmpfile"

    # Should have a result with content
    run jq -e '.result.content[0].text' "$tmpfile"
    [ "$status" -eq 0 ]

    # The text content should be valid JSON (array or object) and non-empty
    local text
    text=$(jq -r '.result.content[0].text' "$tmpfile")
    rm -f "$tmpfile"

    tmpfile=$(mktemp)
    echo "$text" > "$tmpfile"
    run jq -e 'length > 0' "$tmpfile"
    rm -f "$tmpfile"
    [ "$status" -eq 0 ]
}
