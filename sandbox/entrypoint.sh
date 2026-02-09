#!/bin/bash

# 🏰 POCKETCODER SANDBOX ENTRYPOINT
# This script ensures the tmux server is running on the shared socket
# and then optionally starts the Bun listener for future extensibility.

# Start sshd
echo "🔑 [PocketCoder] Starting SSH Daemon on port 2222..."
/usr/sbin/sshd

# Start the SSH Key Sync Loop (Background)
(
  while true; do
    /usr/local/bin/sync_keys.sh
    sleep 300 # Sync every 5 minutes
  done
) &

# Ensure /tmp/tmux exists and is accessible for the worker user
mkdir -p /tmp/tmux
chmod 777 /tmp/tmux

# Keep the container alive by tailing the tmux session output OR just sleeping
echo "✅ [PocketCoder] Sandbox is LIVE and waiting for direct commands."
tail -f /dev/null
