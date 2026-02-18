#!/bin/sh
# opencode_entrypoint.sh
# Standard entrypoint for the OpenCode container.

set -e

echo "🛡️  [PocketCoder] Initializing Environment..."

# 0. SSH Setup - Install authorized key and start sshd
echo "🔐 Setting up SSH access..."

# Create .ssh directory for poco user
mkdir -p /home/poco/.ssh
chmod 700 /home/poco/.ssh

# Copy authorized public key from mounted volume
if [ -f /ssh_keys/id_rsa.pub ]; then
    cp /ssh_keys/id_rsa.pub /home/poco/.ssh/authorized_keys
    chmod 600 /home/poco/.ssh/authorized_keys
    echo "✅ SSH authorized key installed"
else
    echo "⚠️  SSH key not found at /ssh_keys/id_rsa.pub"
fi

# Set correct ownership
chown -R poco:poco /home/poco/.ssh

# Start sshd daemon on port 2222
echo "🚀 Starting sshd on port 2222..."
/usr/sbin/sshd -D -e 2>/tmp/sshd.log &
echo "✅ sshd started"

# 1. Wait for the shell binary to be available (mounted via shared volume from Sandbox)
# This resolves quickly once Sandbox starts and populates the shell_bridge volume.
echo "⏳ Waiting for PocketCoder Shell binary..."
count=0
while [ ! -f /shell_bridge/pocketcoder-shell ]; do
    sleep 1
    count=$((count+1))
    if [ $count -gt 120 ]; then
        echo "❌ Shell binary not found after 120s. Sandbox may not be running."
        exit 1
    fi
done
echo "✅ Shell binary available."

# 2. THE SWITCHEROO (Hard Shell Enforcement)
# In Alpine, /bin/sh is a symlink to Busybox.
# We redirect /bin/sh to our shell bridge, while keeping /bin/ash as the "escape hatch" for system scripts.
# This MUST happen before OpenCode starts since it uses /bin/sh for command execution.
if [ -L /bin/sh ] && [ "$(readlink /bin/sh)" != "/shell_bridge/pocketcoder-shell" ]; then
    echo "🔒 Hardening Shell: /bin/sh -> /shell_bridge/pocketcoder-shell..."
    ln -sf /shell_bridge/pocketcoder-shell /bin/sh
    echo "✅ Shell is now HARDENED."
else
    echo "🔒 Shell already hardened or custom state detected."
fi

# 3. Background: Wait for Sandbox health + MCP, then log readiness
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

# 4. Background Log Tailing (for visibility)
(
    while [ ! -d /root/.local/share/opencode/log ]; do sleep 2; done
    while [ -z "$(ls /root/.local/share/opencode/log/*.log 2>/dev/null)" ]; do sleep 1; done
    echo "📊 [Relay] Log stream active."
    tail -f /root/.local/share/opencode/log/*.log
) &

# 5. Launch OpenCode immediately — don't block on Sandbox
echo "🚀 Launching OpenCode Reasoning Engine..."
exec opencode "$@"
