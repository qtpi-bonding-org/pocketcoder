#!/usr/bin/env bash
# tests/helpers/mcp.sh
# MCP Gateway test helpers
#
# Provides functions for interacting with the MCP gateway via the MCP protocol.
# These use the `docker mcp tools call` command from inside the sandbox container,
# which communicates with the running gateway over SSE — the real Dynamic MCP path.
#
# Usage: load '../../helpers/mcp.sh'

# Gateway endpoint (reachable from sandbox and pocketbase on pocketcoder-mcp network)
MCP_GATEWAY_SSE="${MCP_GATEWAY_SSE:-http://mcp-gateway:8811/sse}"

# ---------------------------------------------------------------------------
# mcp_tools_call — call an MCP tool on the gateway
#
# The `docker mcp` CLI uses stdio transport — it runs `docker mcp gateway run`
# as a subprocess. We run this from inside the GATEWAY container because:
# 1. It has the docker socket to spin up MCP server containers
# 2. It has the `docker mcp` CLI installed
# 3. The catalog file is mounted at /root/.docker/mcp/docker-mcp.yaml
#
# IMPORTANT: The docker mcp CLI does NOT accept JSON for simple arguments.
# Use key=value syntax: docker mcp tools call mcp-add name=fetch
# (Verified in test-mcp-install sandbox, documented in IMPLEMENTATION_SPEC.md)
#
# Args:
#   $1 — tool name (e.g., "mcp-find", "mcp-add", "mcp-remove")
#   $@ (remaining) — key=value argument pairs (e.g., name=fetch query=terraform)
#   Last numeric arg is treated as timeout if it matches pattern
#
# Returns: tool output on stdout, exit code 0 on success
# ---------------------------------------------------------------------------
mcp_tools_call() {
    local tool_name="$1"
    shift
    local timeout=60
    local args=()

    # Collect key=value args; last arg can be a timeout override
    for arg in "$@"; do
        args+=("$arg")
    done

    docker exec pocketcoder-mcp-gateway \
        timeout "$timeout" \
        docker mcp tools call "$tool_name" "${args[@]}" 2>&1
}

# ---------------------------------------------------------------------------
# mcp_find_server — search the gateway catalog for a server by name
#
# Uses the mcp-find primordial tool exposed by the gateway.
# Uses key=value syntax per IMPLEMENTATION_SPEC.md.
#
# Args:
#   $1 — search query (server name or keyword)
#
# Returns: search results on stdout
# ---------------------------------------------------------------------------
mcp_find_server() {
    local query="$1"
    mcp_tools_call "mcp-find" "query=$query"
}

# ---------------------------------------------------------------------------
# mcp_add_server — add a server to the current gateway session
#
# This is the command that actually triggers container spin-up.
# The gateway pulls the image and starts the container.
# Uses key=value syntax per IMPLEMENTATION_SPEC.md.
#
# Args:
#   $1 — server name (e.g., "fetch", "duckduckgo")
#
# Returns: add result on stdout
# ---------------------------------------------------------------------------
mcp_add_server() {
    local server_name="$1"
    docker exec pocketcoder-mcp-gateway \
        timeout 120 \
        docker mcp tools call mcp-add "name=$server_name" 2>&1
}

# ---------------------------------------------------------------------------
# mcp_remove_server — remove a server from the current gateway session
#
# Uses key=value syntax per IMPLEMENTATION_SPEC.md.
#
# Args:
#   $1 — server name
#
# Returns: remove result on stdout
# ---------------------------------------------------------------------------
mcp_remove_server() {
    local server_name="$1"
    mcp_tools_call "mcp-remove" "name=$server_name"
}

# ---------------------------------------------------------------------------
# mcp_list_tools — list all tools available on the gateway
#
# Uses `docker mcp tools ls` from the sandbox.
#
# Returns: tool list on stdout
# ---------------------------------------------------------------------------
mcp_list_tools() {
    docker exec pocketcoder-sandbox \
        docker mcp tools ls 2>&1
}

# ---------------------------------------------------------------------------
# mcp_server_enable — enable a server in the local CLI config
#
# NOTE: This modifies the local CLI registry. It does NOT trigger Dynamic MCP
# container spin-up. Use mcp_add_server for that.
#
# Args:
#   $1 — server name
#
# Returns: enable output on stdout
# ---------------------------------------------------------------------------
mcp_server_enable() {
    local server_name="$1"
    docker exec pocketcoder-sandbox \
        docker mcp server enable "$server_name" 2>&1
}

# ---------------------------------------------------------------------------
# mcp_server_disable — disable a server in the local CLI config
#
# Args:
#   $1 — server name
#
# Returns: disable output on stdout
# ---------------------------------------------------------------------------
mcp_server_disable() {
    local server_name="$1"
    docker exec pocketcoder-sandbox \
        docker mcp server disable "$server_name" 2>&1
}

# ---------------------------------------------------------------------------
# snapshot_containers — capture a sorted list of running container names
#
# Returns: newline-separated sorted container names on stdout
# ---------------------------------------------------------------------------
snapshot_containers() {
    docker ps --format '{{.Names}}' | sort
}

# ---------------------------------------------------------------------------
# count_containers — count running containers
#
# Returns: integer count on stdout
# ---------------------------------------------------------------------------
count_containers() {
    docker ps --format '{{.Names}}' | wc -l | tr -d ' '
}

# ---------------------------------------------------------------------------
# diff_containers — find containers that appeared between two snapshots
#
# Args:
#   $1 — "before" snapshot (newline-separated names)
#   $2 — "after" snapshot (newline-separated names)
#
# Returns: newline-separated list of new container names
# ---------------------------------------------------------------------------
diff_containers() {
    local before="$1"
    local after="$2"
    comm -13 <(echo "$before") <(echo "$after")
}

# ---------------------------------------------------------------------------
# wait_for_new_container — poll until a new container appears
#
# Args:
#   $1 — "before" snapshot (newline-separated names)
#   $2 — timeout in seconds (default: 60)
#   $3 — optional name pattern to match (grep -i)
#
# Returns: new container name(s) on stdout, exit 0 if found, 1 on timeout
# ---------------------------------------------------------------------------
wait_for_new_container() {
    local before="$1"
    local timeout="${2:-60}"
    local pattern="${3:-}"

    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout))

    while [ "$(date +%s)" -lt "$end_time" ]; do
        local after
        after=$(snapshot_containers)
        local new
        new=$(diff_containers "$before" "$after")

        if [ -n "$new" ]; then
            if [ -n "$pattern" ]; then
                local matched
                matched=$(echo "$new" | grep -i "$pattern" || true)
                if [ -n "$matched" ]; then
                    echo "$matched"
                    return 0
                fi
            else
                echo "$new"
                return 0
            fi
        fi

        sleep 2
    done

    return 1
}

# ---------------------------------------------------------------------------
# assert_container_spun_up — hard assertion that a new container appeared
#
# This is the money shot. Call this after mcp_add_server to prove a container
# was actually created by the gateway.
#
# Args:
#   $1 — "before" snapshot
#   $2 — server name pattern to match
#   $3 — timeout (default: 90)
#
# Fails the BATS test if no matching container appears.
# ---------------------------------------------------------------------------
assert_container_spun_up() {
    local before="$1"
    local pattern="$2"
    local timeout="${3:-90}"

    local new_containers
    new_containers=$(wait_for_new_container "$before" "$timeout" "$pattern")

    if [ -z "$new_containers" ]; then
        local after
        after=$(snapshot_containers)
        echo "❌ ASSERTION FAILED: No new container matching '$pattern' appeared after ${timeout}s" >&2
        echo "  Containers before:" >&2
        echo "$before" | sed 's/^/    /' >&2
        echo "  Containers after:" >&2
        echo "$after" | sed 's/^/    /' >&2
        echo "  All running containers:" >&2
        docker ps --format '{{.Names}} ({{.Image}})' | sed 's/^/    /' >&2
        return 1
    fi

    echo "✓ New container(s) matching '$pattern':"
    echo "$new_containers" | sed 's/^/    /'
    return 0
}

# Export for BATS
export -f mcp_tools_call mcp_find_server mcp_add_server mcp_remove_server
export -f mcp_list_tools mcp_server_enable mcp_server_disable
export -f snapshot_containers count_containers diff_containers
export -f wait_for_new_container assert_container_spun_up
