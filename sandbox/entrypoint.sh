#!/bin/bash
# PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
# Copyright (C) 2026 Qtpi Bonding LLC
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# @pocketcoder-core: Sandbox Entrypoint. Hardens the environment and sets up Tmux.
# PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
# Copyright (C) 2026 Qtpi Bonding LLC

echo "🏗️  [PocketCoder] Initializing Hardened Sandbox..."

# --- 🧹 CLEANUP RITUAL (Ensuring Statelessness) ---
echo "🧹 Cleaning up stale sockets and locks..."

# 1. Wipe TMUX sockets to prevent 'Address already in use' or 'Ghost' sessions
rm -rf /tmp/tmux/*
mkdir -p /tmp/tmux
chmod 777 /tmp/tmux

# 2. Clear CAO internal lock/journal files
CAO_HOME_BASE="/root/.aws/cli-agent-orchestrator"
if [ -d "$CAO_HOME_BASE" ]; then
    echo "🔍 Clearing stale CAO state from $CAO_HOME_BASE..."
    find "$CAO_HOME_BASE" -name "*.db-journal" -delete
    find "$CAO_HOME_BASE" -name "*.lock" -delete
    find "$CAO_HOME_BASE" -name "*.pid" -delete
fi
# 3. Mount shared binary
if [ -f "/usr/local/bin/proxy_share/pocketcoder" ]; then
    echo "🔗 Linking shared 'pocketcoder' binary..."
    ln -sf /usr/local/bin/proxy_share/pocketcoder /usr/local/bin/pocketcoder
    chmod +x /usr/local/bin/pocketcoder
fi

# --- 🔗 POPULATE SHARED SHELL BRIDGE VOLUME ---
# Explicitly copy binaries into the shared volume so OpenCode can access them
# regardless of container start order (Docker volume init is non-deterministic).
echo "🔗 Populating shell_bridge shared volume..."
cp -f /app/pocketcoder /app/shell_bridge/pocketcoder
chmod +x /app/shell_bridge/pocketcoder
# Recreate the wrapper script in case the volume was initialized empty
printf '#!/bin/bash\n/app/shell_bridge/pocketcoder shell "$@"\n' > /app/shell_bridge/pocketcoder-shell
chmod +x /app/shell_bridge/pocketcoder-shell
echo "✅ Shell bridge binaries ready."

# --- 🖥️ TMUX SETUP (Phase 2: Sandbox owns tmux) ---
echo "🖥️ Creating tmux session..."
tmux -S /tmp/tmux/pocketcoder new-session -d -s pocketcoder_session -n main
chmod 777 /tmp/tmux/pocketcoder

# Start the Rust axum server in the background
echo "🚀 Starting PocketCoder axum server on port 3001..."
/app/pocketcoder server --port 3001 &

# --- 🚀 SERVICE STARTUP ---

# 4. Start sshd
echo "🔑 Starting SSH Daemon on port 2222..."
mkdir -p /var/run/sshd
/usr/sbin/sshd

# 4. SSH Key Localization (Smart Retry)
# We copy from the read-only host mount to the worker's home with correct perms.
# We poll until the key is found, then we stop polling to save resources.
echo "🔄 Localizing SSH keys for 'worker' user..."
(
  # Attempt 10 times with 1s sleep to handle mount race condition
  for i in {1..10}; do
    /usr/local/bin/sync_keys.sh > /dev/null 2>&1
    if [ -s "/home/worker/.ssh/authorized_keys" ]; then
      echo "✅ [PocketCoder] SSH Key localized successfully."
      break
    fi
    echo "⏳ Waiting for SSH key volume mount... (Attempt $i/10)"
    sleep 1
  done
) &

# 5. Start CAO API Server (The Conductor)
echo "🤖 Starting CAO API Server on port 9889..."
(
  export CAO_SERVER_HOST=0.0.0.0
  export PYTHONUNBUFFERED=1
  cd /app/cao && /usr/local/bin/uv run cao-server
) &

# 6. Start CAO MCP Server (SSE Mode) (Background)
echo "🤖 Starting CAO MCP Server (SSE) on port 9888..."
(
  export CAO_MCP_TRANSPORT=sse
  export CAO_MCP_PORT=9888
  export PYTHONUNBUFFERED=1
  export CAO_LOG_LEVEL=INFO
  export PUBLIC_URL=http://localhost:9889
  cd /app/cao && /usr/local/bin/uv run cao-mcp-server
) &

# 7. Wait for OpenCode sshd and create Poco window (Phase 2: SSH bridge)
echo "⏳ Waiting for OpenCode sshd to be ready..."
RETRY_COUNT=0
while true; do
    if timeout 2 bash -c 'exec 3<>/dev/tcp/opencode/2222 && exec 3>&- && exec 3<&-' 2>/dev/null; then
        echo "✅ OpenCode sshd is ready!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "⏳ OpenCode sshd not ready, retrying in 2 seconds... (attempt $RETRY_COUNT)"
    sleep 2
done

echo "🪟 Creating Poco window via SSH bridge..."
tmux -S /tmp/tmux/pocketcoder new-window \
    -t pocketcoder_session -n poco \
    "ssh -t -o StrictHostKeyChecking=no -i /ssh_keys/id_rsa poco@opencode -p 2222"
echo "✅ Poco window created."

# 8. Pane health watchdog - ensure Poco window always exists
echo "🔍 Starting pane health watchdog..."
(
    while true; do
        if ! tmux -S /tmp/tmux/pocketcoder list-windows -t pocketcoder_session \
             | grep -q "poco"; then
            echo "⚠️ Poco window missing, recreating..."
            tmux -S /tmp/tmux/pocketcoder new-window \
                -t pocketcoder_session -n poco \
                "ssh -t -o StrictHostKeyChecking=no -i /ssh_keys/id_rsa poco@opencode -p 2222"
        fi
        sleep 10
    done
) &

# 9. Register Poco terminal with CAO (Requirement 6.1)
echo "🔗 Registering Poco terminal with CAO..."
while ! curl -s http://localhost:9889/health > /dev/null 2>&1; do
    sleep 1
done
curl -s -X POST "http://localhost:9889/sessions" \
    -G \
    --data-urlencode "provider=opencode-attach" \
    --data-urlencode "agent_profile=poco" \
    --data-urlencode "session_name=pocketcoder_session" \
    --data-urlencode "delegating_agent_id=poco"
echo "✅ Poco registered with CAO."

echo "✅ [PocketCoder] Sandbox is LIVE and HARDENED."
tail -f /dev/null
