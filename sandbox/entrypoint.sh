#!/bin/bash

# 🏰 POCKETCODER SANDBOX ENTRYPOINT
# This script ensures the tmux server is running on the shared socket
# and then optionally starts the Bun listener for future extensibility.

mkdir -p /tmp/tmux
chmod 777 /tmp/tmux

# Start tmux server if not already running on the shared socket
if ! tmux -S /tmp/tmux/pocketcoder has-session -t pocketcoder_session 2>/dev/null; then
    echo "🧶 [PocketCoder] Initializing Sandbox Tmux Session on shared socket..."
    tmux -S /tmp/tmux/pocketcoder new-session -d -s pocketcoder_session
fi

# Bring the Bun listener up in the background (for future non-tmux MCP tools)
echo "🚀 [PocketCoder] Starting Bun Listener in background..."
bun run /sandbox/listener.ts &

# Keep the container alive by tailing the tmux session output OR just sleeping
echo "✅ [PocketCoder] Sandbox is LIVE and waiting for direct commands."
tail -f /dev/null
