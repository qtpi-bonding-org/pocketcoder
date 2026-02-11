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


# @pocketcoder-core: Runtime Boot. Starts SSHD and ensures the tmux socket is shared.
# @pocketcoder-core: Key Guard. Periodically pulls authorized keys from the API into the sandbox.
# 🗝️ POCKETCODER SSH SYNC
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
