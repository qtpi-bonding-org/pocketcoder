#!/bin/bash
set -euo pipefail
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

# --- PIDs for critical processes ---
PROXY_PID=""
AGENTS_PID=""

# --- 🛡️ SIGNAL HANDLING ---
# Trap SIGTERM/SIGINT to cleanly shut down child processes.
# tini (init: true) forwards signals here; we propagate to children.
cleanup() {
    echo "🛑 [PocketCoder] Shutdown signal received, cleaning up..."
    [ -n "$AGENTS_PID" ] && kill "$AGENTS_PID" 2>/dev/null
    [ -n "$PROXY_PID" ] && kill "$PROXY_PID" 2>/dev/null
    # sshd manages its own children; sending TERM is sufficient
    killall sshd 2>/dev/null
    wait 2>/dev/null
    echo "👋 [PocketCoder] Sandbox shut down cleanly."
    exit 0
}
trap cleanup SIGTERM SIGINT

# --- 🧹 CLEANUP RITUAL (Ensuring Statelessness) ---
echo "🧹 Cleaning up stale sockets and locks..."
rm -rf /tmp/tmux/*
mkdir -p /tmp/tmux
chmod 777 /tmp/tmux

# --- 🚀 SERVICE STARTUP ---

# 1. Pocketcoder proxy (CRITICAL — opencode shells through this)
echo "🚀 Starting PocketCoder axum server on port 3001..."
/usr/local/bin/pocketcoder server --port 3001 &
PROXY_PID=$!

# 2. SSH daemon (non-critical — container survives without it)
echo "🔑 Starting SSH Daemon on port 2222..."
mkdir -p /var/run/sshd
/usr/sbin/sshd

# 3. SSH Key sync (non-critical, background)
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
  if [ ! -s "/home/worker/.ssh/authorized_keys" ]; then
    echo "⚠️ [Sandbox] SSH key sync failed after all retries"
  fi
) &

# 4. Tmux session
echo "🖥️ Creating tmux session..."
tmux -S "$TMUX_SOCKET" new-session -d -s "$TMUX_SESSION" -n "system"
chmod 777 "$TMUX_SOCKET"
tmux -S "$TMUX_SOCKET" new-window -t "$TMUX_SESSION" -n "poco-terminal" -c /workspace

# 5. Poco-agents (CRITICAL — sub-agent orchestration)
echo "🤖 Starting poco-agents MCP server on port 9888..."
mkdir -p /workspace/.agents
/usr/local/bin/poco-agents &
AGENTS_PID=$!

# Wait for poco-agents to be ready
for i in {1..15}; do
    if curl -s http://localhost:9888/health > /dev/null 2>&1; then
        echo "✅ poco-agents is ready."
        break
    fi
    sleep 1
done
if ! curl -s http://localhost:9888/health > /dev/null 2>&1; then
    echo "⚠️ [Sandbox] poco-agents health check failed after all retries"
fi

echo "✅ [PocketCoder] Sandbox is LIVE and HARDENED."

# --- 🔄 PROCESS MONITOR ---
# Monitor critical processes. If either dies, exit 1 so Docker restarts us.
while true; do
    if ! kill -0 "$PROXY_PID" 2>/dev/null; then
        echo "💀 [PocketCoder] Proxy process (PID $PROXY_PID) died. Exiting for restart."
        exit 1
    fi
    if ! kill -0 "$AGENTS_PID" 2>/dev/null; then
        echo "💀 [PocketCoder] poco-agents process (PID $AGENTS_PID) died. Exiting for restart."
        exit 1
    fi
    sleep 5
done
