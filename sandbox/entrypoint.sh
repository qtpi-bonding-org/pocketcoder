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

# Bring the Listener up (now using tsx)
echo "🚀 [PocketCoder] Starting Listener in background..."
tsx /sandbox/listener.ts &

# Start CAO API Server
echo "🧠 [PocketCoder] Starting CAO Orchestrator API..."
nohup uvicorn cli_agent_orchestrator.api.main:app --host 0.0.0.0 --port 9889 > /tmp/cao_server.log 2>&1 &

# Keep the container alive by tailing the tmux session output OR just sleeping
echo "✅ [PocketCoder] Sandbox is LIVE and waiting for direct commands."
tail -f /dev/null
