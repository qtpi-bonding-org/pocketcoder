#!/bin/bash
# tests/helpers/inspect.sh
# Adapted inspect scripts for BATS usage
# Provides functions to query and display state from containers
# Usage: source helpers/inspect.sh

# Container endpoints (can be overridden by environment)
PB_URL="${PB_URL:-http://localhost:8090}"
OPENCODE_URL="${OPENCODE_URL:-http://localhost:3000}"
SANDBOX_HOST="${SANDBOX_HOST:-localhost}"

# Load environment
load_env() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$script_dir/../test-env.sh" ]; then
        source "$script_dir/../test-env.sh"
    fi
    if [ -f .env ]; then
        set -a
        source .env
        set +a
    fi
}

# Get admin token for PocketBase queries
get_admin_token() {
    load_env
    
    local token_res
    token_res=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{
            \"identity\": \"$POCKETBASE_ADMIN_EMAIL\",
            \"password\": \"$POCKETBASE_ADMIN_PASSWORD\"
        }")
    
    echo "$token_res" | grep -o '"token":"[^"]*"' | cut -d'"' -f4
}

# ============================================================
# PocketBase Inspection Functions
# ============================================================

# Inspect PocketBase collection
# Args: collection [filter]
# Usage: pb_inspect "chats" "?filter=user='...'"
pb_inspect() {
    local collection="$1"
    local filter="${2:-}"
    local token="${3:-$(get_admin_token)}"
    
    echo "🔍 PocketBase Collection: $collection"
    echo "--------------------------------------------------------------------------------"
    
    local url="$PB_URL/api/collections/$collection/records$filter"
    curl -s -X GET "$url" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json" | jq '.'
    
    echo "--------------------------------------------------------------------------------"
}

# Inspect chats collection
# Usage: inspect_chats
inspect_chats() {
    local token="${1:-$(get_admin_token)}"
    echo "🔍 PocketBase Chats"
    echo "--------------------------------------------------------------------------------"
    curl -s -X GET "$PB_URL/api/collections/chats/records" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json" \
        | jq '.items[] | {id, agent_id, title, user, agent, turn, last_active, preview}'
    echo "--------------------------------------------------------------------------------"
}

# Inspect messages collection
# Usage: inspect_messages
inspect_messages() {
    local token="${1:-$(get_admin_token)}"
    echo "🔍 PocketBase Messages"
    echo "--------------------------------------------------------------------------------"
    curl -s -X GET "$PB_URL/api/collections/messages/records" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json" \
        | jq '.items[] | {id, chat, agent_message_id, role, parts, delivery}'
    echo "--------------------------------------------------------------------------------"
}

# Inspect subagents collection
# Usage: inspect_subagents
inspect_subagents() {
    local token="${1:-$(get_admin_token)}"
    echo "🔍 PocketBase Subagents"
    echo "--------------------------------------------------------------------------------"
    curl -s -X GET "$PB_URL/api/collections/subagents/records" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json" \
        | jq '.items[] | {id, subagent_id, delegating_agent_id, tmux_window_id}'
    echo "--------------------------------------------------------------------------------"
}

# Inspect permissions collection
# Usage: inspect_permissions
inspect_permissions() {
    local token="${1:-$(get_admin_token)}"
    echo "🔍 PocketBase Permissions"
    echo "--------------------------------------------------------------------------------"
    curl -s -X GET "$PB_URL/api/collections/permissions/records" \
        -H "Authorization: $token" \
        -H "Content-Type: application/json" \
        | jq '.items[] | {id, chat, agent_permission_id, status, command}'
    echo "--------------------------------------------------------------------------------"
}

# ============================================================
# OpenCode Inspection Functions
# ============================================================

# Inspect OpenCode session status
# Args: session_id
# Usage: inspect_opencode_session "session123"
inspect_opencode_session() {
    local session_id="$1"
    
    if [ -z "$session_id" ]; then
        echo "Usage: inspect_opencode_session <session_id>"
        return 1
    fi
    
    echo "🔍 OpenCode Session: $session_id"
    echo "--------------------------------------------------------------------------------"
    
    local response
    response=$(curl -s -w "\n%{http_code}" "$OPENCODE_URL/session/$session_id")
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        echo "Status: ACTIVE"
        echo "$body" | jq '.'
    else
        echo "Status: NOT FOUND (HTTP $http_code)"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    fi
    
    echo "--------------------------------------------------------------------------------"
}

# Check OpenCode health
# Usage: inspect_opencode_health
inspect_opencode_health() {
    echo "🔍 OpenCode Health Check"
    echo "--------------------------------------------------------------------------------"
    
    local response
    response=$(curl -s -w "\n%{http_code}" "$OPENCODE_URL/health")
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    echo "HTTP Status: $http_code"
    echo "Response: $body"
    
    echo "--------------------------------------------------------------------------------"
}

# ============================================================
# CAO/Sandbox Inspection Functions
# ============================================================

# Inspect CAO terminals from SQLite database
# Usage: inspect_cao_terminals
inspect_cao_terminals() {
    echo "🗄️  CAO Database - Terminals"
    echo "--------------------------------------------------------------------------------"
    echo "Fields: delegating_agent_id, tmux_session, tmux_window_id"
    echo "--------------------------------------------------------------------------------"
    
    docker exec pocketcoder-sandbox python3 -c "
import sqlite3, json, sys
conn = sqlite3.connect('/root/.aws/cli-agent-orchestrator/db/cli-agent-orchestrator.db')
conn.row_factory = sqlite3.Row
cursor = conn.cursor()
cursor.execute('SELECT id, tmux_session, tmux_window, tmux_window_id, agent_profile, provider, external_session_id as delegating_agent_id FROM terminals')
rows = [dict(row) for row in cursor.fetchall()]
print(json.dumps(rows, indent=2))
" 2>/dev/null || echo "  (Could not connect to CAO database)"
    
    echo "--------------------------------------------------------------------------------"
}

# Inspect tmux sessions and windows
# Usage: inspect_tmux
inspect_tmux() {
    echo "🪟 Tmux Sessions and Windows"
    echo "--------------------------------------------------------------------------------"
    
    echo "Sessions:"
    docker exec pocketcoder-sandbox tmux list-sessions 2>/dev/null || echo "  (no sessions found)"
    
    echo ""
    echo "Windows:"
    docker exec pocketcoder-sandbox bash -c 'for s in $(tmux list-sessions -F "#S" 2>/dev/null); do echo "  Session $s:"; tmux list-windows -t "$s" -F "    [#{window_id}] #{window_name}"; done' 2>/dev/null || echo "  (no windows found)"
    
    echo "--------------------------------------------------------------------------------"
}

# ============================================================
# Combined Inspection Functions
# ============================================================

# Full system inspection for debugging
# Usage: inspect_all
inspect_all() {
    echo "=================================================="
    echo "         SYSTEM INSPECTION REPORT"
    echo "=================================================="
    echo ""
    
    echo "--- PocketBase ---"
    inspect_chats
    echo ""
    
    echo "--- OpenCode ---"
    inspect_opencode_health
    echo ""
    
    echo "--- CAO Terminals ---"
    inspect_cao_terminals
    echo ""
    
    echo "--- Tmux ---"
    inspect_tmux
    echo ""
    
    echo "=================================================="
}

# Quick status check
# Usage: quick_status
quick_status() {
    echo "=== Quick Status Check ==="
    
    # Check PocketBase
    if curl -s -o /dev/null -w "%{http_code}" "$PB_URL/api/health" | grep -q "200"; then
        echo "✓ PocketBase: OK"
    else
        echo "✗ PocketBase: DOWN"
    fi
    
    # Check OpenCode
    if curl -s -o /dev/null -w "%{http_code}" "$OPENCODE_URL/health" | grep -q "200"; then
        echo "✓ OpenCode: OK"
    else
        echo "✗ OpenCode: DOWN"
    fi
    
    # Check Sandbox
    if nc -z "$SANDBOX_HOST" 3001 2>/dev/null; then
        echo "✓ Sandbox: OK"
    else
        echo "✗ Sandbox: DOWN"
    fi
    
    # Check tmux
    if docker exec pocketcoder-sandbox tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "✓ Tmux: OK"
    else
        echo "✗ Tmux: DOWN"
    fi
}

# Export functions for use in BATS
export -f pb_inspect inspect_chats inspect_messages inspect_subagents inspect_permissions
export -f inspect_opencode_session inspect_opencode_health
export -f inspect_cao_terminals inspect_tmux
export -f inspect_all quick_status