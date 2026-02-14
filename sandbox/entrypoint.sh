#!/bin/bash
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

# --- 🚀 SERVICE STARTUP ---

# 3. Start sshd
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
  cd /app/cao && /usr/local/bin/uv run cao-mcp-server
) &

# 7. Start the core TMUX session
echo "🧵 Initializing TMUX Session 'pocketcoder_session'..."
/usr/bin/tmux -S /tmp/tmux/pocketcoder new-session -d -s pocketcoder_session -n main "/bin/bash"
chmod 777 /tmp/tmux/pocketcoder

echo "✅ [PocketCoder] Sandbox is LIVE and HARDENED."
tail -f /dev/null
