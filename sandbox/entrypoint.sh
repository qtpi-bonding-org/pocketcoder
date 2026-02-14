#!/bin/bash
# PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
# Copyright (C) 2026 Qtpi Bonding LLC

# Start sshd
echo "🔑 [PocketCoder] Starting SSH Daemon on port 2222..."
/usr/sbin/sshd

# Start the SSH Key Sync Loop (Background)
(
  while true; do
    /usr/local/bin/sync_keys.sh
    sleep 2 # Aggressive polling for instant key sync
  done
) &

# Ensure /tmp/tmux exists and is accessible for the worker user
mkdir -p /tmp/tmux
chmod 777 /tmp/tmux

# Start CAO MCP Server in SSE Mode (Background)
echo "🤖 [PocketCoder] Starting CAO MCP Server (SSE) on port 9888..."
(
  export CAO_MCP_TRANSPORT=http
  export CAO_MCP_PORT=9888
  export PYTHONUNBUFFERED=1
  export CAO_LOG_LEVEL=DEBUG
  cd /app/cao && uv run cao-mcp-server
) &

# Start CAO Server (Background)
echo "🤖 [PocketCoder] Starting CAO Server on port 9889..."
(
  cd /app/cao && CAO_SERVER_HOST=0.0.0.0 uv run cao-server
) &

# Start the core TMUX session that the Proxy will attach to
echo "🧵 [PocketCoder] Initializing TMUX Session 'pocketcoder_session' on /tmp/tmux/pocketcoder..."
tmux -S /tmp/tmux/pocketcoder new-session -d -s pocketcoder_session -n main "/bin/bash"
chmod 777 /tmp/tmux/pocketcoder

echo "✅ [PocketCoder] Sandbox is LIVE and waiting for direct commands."
tail -f /dev/null
