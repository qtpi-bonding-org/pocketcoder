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

# 2. Mount shared binary
if [ -f "/usr/local/bin/proxy_share/pocketcoder" ]; then
    echo "🔗 Linking shared 'pocketcoder' binary..."
    ln -sf /usr/local/bin/proxy_share/pocketcoder /usr/local/bin/pocketcoder
    chmod +x /usr/local/bin/pocketcoder
fi

# --- 🖥️ TMUX SETUP ---
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
  if [ ! -s "/home/worker/.ssh/authorized_keys" ]; then
    echo "⚠️ [Sandbox] SSH key sync failed after all retries"
  fi
) &

# --- TMUX SESSION ---
echo "🖥️ Creating tmux session..."
tmux -S "$TMUX_SOCKET" new-session -d -s "$TMUX_SESSION" -n "system"
chmod 777 "$TMUX_SOCKET"

# Create default terminal window for Poco (used by /exec endpoint)
tmux -S "$TMUX_SOCKET" new-window -t "$TMUX_SESSION" -n "poco-terminal" -c /workspace

# --- POCO-AGENTS ---
echo "🤖 Starting poco-agents MCP server on port 9888..."
mkdir -p /workspace/.agents
/usr/local/bin/poco-agents &

for i in {1..15}; do
    if curl -s http://localhost:9888/health > /dev/null 2>&1; then
        echo "✅ poco-agents is ready."
        break
    fi
    sleep 1
done

echo "✅ [PocketCoder] Sandbox is LIVE and HARDENED."
tail -f /dev/null
