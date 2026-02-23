#!/bin/sh
# opencode_entrypoint.sh
# Standard entrypoint for the OpenCode container.

set -e

echo "🛡️  [PocketCoder] Initializing Environment..."

# 1. THE SWITCHEROO (Hard Shell Enforcement)
# In Alpine, /bin/sh is a symlink to Busybox.
# We redirect /bin/sh to our shell bridge, while keeping /bin/ash as the "escape hatch" for system scripts.
# This MUST happen before OpenCode starts since it uses /bin/sh for command execution.
if [ -L /bin/sh ] && [ "$(readlink /bin/sh)" != "/usr/local/bin/pocketcoder-shell" ]; then
    echo "🔒 Hardening Shell: /bin/sh -> /usr/local/bin/pocketcoder-shell..."
    ln -sf /usr/local/bin/pocketcoder-shell /bin/sh
    echo "✅ Shell is now HARDENED."
else
    echo "🔒 Shell already hardened or custom state detected."
fi

# 2. Background: Wait for Sandbox health + MCP, then log readiness
# These checks run in the background so they don't block OpenCode startup.
# This breaks the circular dependency: Sandbox depends on OpenCode being healthy,
# so OpenCode must start without waiting for Sandbox.
(
    echo "⏳ [Background] Waiting for Sandbox Server..."
    sb_count=0
    while ! curl -s http://sandbox:3001/health > /dev/null 2>&1; do
        sleep 2
        sb_count=$((sb_count+1))
        if [ $sb_count -gt 60 ]; then
            echo "⚠️  [Background] Sandbox not reachable after 120s, OpenCode running without it."
            break
        fi
    done
    if [ $sb_count -le 60 ]; then
        echo "✅ [Background] Sandbox is UP."
    fi

    echo "⏳ [Background] Waiting for MCP server (via sandbox)..."
    mcp_count=0
    while true; do
        mcp_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 http://sandbox:9888/sse 2>/dev/null || true)
        if [ "$mcp_status" = "200" ]; then
            echo "✅ [Background] MCP server is reachable through sandbox."
            break
        fi
        mcp_count=$((mcp_count+1))
        if [ $mcp_count -gt 60 ]; then
            echo "⚠️  [Background] MCP server not reachable after 60 attempts."
            break
        fi
        sleep 2
    done
) &

# 3. Background Log Tailing (for visibility)
(
    while [ ! -d /root/.local/share/opencode/log ]; do sleep 2; done
    while [ -z "$(ls /root/.local/share/opencode/log/*.log 2>/dev/null)" ]; do sleep 1; done
    echo "📊 [Relay] Log stream active."
    tail -f /root/.local/share/opencode/log/*.log
) &

# 4. Launch OpenCode immediately — don't block on Sandbox
echo "🚀 Launching OpenCode Reasoning Engine..."
exec opencode "$@"
