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

# --- Constants ---
TMUX_SOCKET="/tmp/tmux/pocketcoder"
TMUX_SESSION="pocketcoder"
POCO_WINDOW="poco"    # The Poco TUI window (SSH bridge to OpenCode)

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

# --- 🖥️ TMUX SETUP ---
# Socket directory only. CAO creates the session + exec window during registration.
# The proxy targets that window by NAME (not index) for resilience.
echo "🖥️ Preparing tmux socket directory..."
mkdir -p /tmp/tmux
chmod 777 /tmp/tmux

# Start the Rust axum server in the background
echo "🚀 Starting PocketCoder axum server on port 3001..."
/usr/local/bin/pocketcoder server --port 3001 &

# --- 🚀 SERVICE STARTUP ---

# 4. Start sshd
echo "🔑 Starting SSH Daemon on port 2222..."
mkdir -p /var/run/sshd
/usr/sbin/sshd

# 4. SSH Key Localization (Smart Retry)
echo "🔄 Localizing SSH keys for 'worker' user..."
(
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

# 6. (DEFERRED) Start CAO MCP Server (SSE Mode) (Background)
# We wait until CAO API is ready before starting this to prevent DB race conditions.

# 7. Wait for OpenCode sshd to be ready
echo "⏳ Waiting for OpenCode sshd to be ready..."
RETRY_COUNT=0
MAX_RETRIES=60  # 120 seconds total

while true; do
    if timeout 2 bash -c 'exec 3<>/dev/tcp/opencode/2222 && exec 3>&- && exec 3<&-' 2>/dev/null; then
        echo "✅ OpenCode sshd is ready!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "❌ OpenCode sshd not ready after 120s"
        echo "   This usually means OpenCode container failed to start"
        echo "   Check OpenCode logs: docker logs pocketcoder-opencode"
        exit 1
    fi
    
    echo "⏳ OpenCode sshd not ready, retrying in 2 seconds... (attempt $RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

# 8. Register Poco terminal with CAO (Requirement 6.1)
# CAO creates the tmux session + initial exec window + terminal DB record.
# The proxy will resolve the window NAME from CAO and target it directly.
echo "🔗 Registering Poco terminal with CAO..."

# Wait for CAO API with timeout
CAO_READY=false
for i in {1..30}; do
    if curl -s http://localhost:9889/health > /dev/null 2>&1; then
        # Double-check with a small delay to ensure full initialization
        sleep 1
        CAO_READY=true
        break
    fi
    echo "⏳ Waiting for CAO API (attempt $i/30)..."
    sleep 2
done

if [ "$CAO_READY" = false ]; then
    echo "❌ CAO API not ready after 60s"
    echo "   Check CAO logs in sandbox container"
    exit 1
fi

# 6b. Start CAO MCP Server now that API/DB is healthy
echo "🤖 Starting CAO MCP Server (SSE) on port 9888..."
(
  export CAO_MCP_TRANSPORT=sse
  export CAO_MCP_PORT=9888
  export PYTHONUNBUFFERED=1
  export CAO_LOG_LEVEL=INFO
  export PUBLIC_URL=http://localhost:9889
  cd /app/cao && /usr/local/bin/uv run cao-mcp-server
) &

# Attempt registration with validation
CAO_RESPONSE=$(curl -s -X POST "http://localhost:9889/sessions" \
    -G \
    --data-urlencode "provider=opencode-attach" \
    --data-urlencode "agent_profile=poco" \
    --data-urlencode "session_name=$TMUX_SESSION" \
    --data-urlencode "delegating_agent_id=pocketcoder" \
    --data-urlencode "target_window_name=poco:terminal")

echo "CAO response: $CAO_RESPONSE"

# Validate response contains expected fields
if echo "$CAO_RESPONSE" | grep -q '"name"'; then
    echo "✅ CAO registration successful"
else
    echo "❌ CAO registration failed!"
    echo "   Response: $CAO_RESPONSE"
    echo "   Check CAO API logs for details"
    exit 1
fi

# Extract the window name CAO assigned (e.g. "poco-ab12") so the watchdog knows it
EXEC_WINDOW=$(echo "$CAO_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('name',''))" 2>/dev/null || echo "")
if [ -z "$EXEC_WINDOW" ]; then
    echo "⚠️ Could not extract exec window name from CAO response, falling back to tmux query"
    EXEC_WINDOW=$(tmux -S "$TMUX_SOCKET" list-windows -t "$TMUX_SESSION" -F '#{window_name}' 2>/dev/null | head -1)
    if [ -z "$EXEC_WINDOW" ]; then
        echo "❌ No exec window found in tmux session!"
        echo "   Tmux session may not have been created properly"
        tmux -S "$TMUX_SOCKET" list-windows -t "$TMUX_SESSION" 2>&1 || echo "   Session does not exist"
        exit 1
    fi
fi
echo "✅ Poco registered with CAO. Exec window: $EXEC_WINDOW"

# Make tmux socket world-accessible
chmod 777 "$TMUX_SOCKET"

# 9. Create Poco TUI window via SSH bridge into OpenCode
# This is a SEPARATE window from the exec window. CAO's async messaging
# (send_keys) targets the exec window by name. The Poco TUI is for the
# interactive SSH bridge.
echo "🪟 Creating Poco TUI window via SSH bridge..."
tmux -S "$TMUX_SOCKET" new-window \
    -t "$TMUX_SESSION" -n "$POCO_WINDOW" \
    "ssh -t -o StrictHostKeyChecking=no -i /ssh_keys/id_rsa poco@opencode -p 2222"
echo "✅ Poco TUI window created."

# 10. Window health watchdog - ensure both windows always exist
echo "🔍 Starting window health watchdog..."
(
    while true; do
        # Check exec window (CAO's command pane, used by proxy)
        if [ -n "$EXEC_WINDOW" ]; then
            if ! tmux -S "$TMUX_SOCKET" list-windows -t "$TMUX_SESSION" 2>/dev/null \
                 | grep -q "$EXEC_WINDOW"; then
                echo "⚠️ Exec window '$EXEC_WINDOW' missing, recreating..."
                tmux -S "$TMUX_SOCKET" new-window -t "$TMUX_SESSION" -n "$EXEC_WINDOW"
            fi
        fi
        # Check poco TUI window (SSH bridge)
        if ! tmux -S "$TMUX_SOCKET" list-windows -t "$TMUX_SESSION" 2>/dev/null \
             | grep -q "$POCO_WINDOW"; then
            echo "⚠️ Poco TUI window missing, recreating..."
            tmux -S "$TMUX_SOCKET" new-window \
                -t "$TMUX_SESSION" -n "$POCO_WINDOW" \
                "ssh -t -o StrictHostKeyChecking=no -i /ssh_keys/id_rsa poco@opencode -p 2222"
        fi
        sleep 10
    done
) &

# 11. Final registration confirmation
echo "✅ [PocketCoder] Sandbox is LIVE and HARDENED."
tail -f /dev/null
