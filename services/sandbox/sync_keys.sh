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


# @pocketcoder-core: Key Guard. Periodically pulls authorized keys from the PocketBase API.
# 🔑 POCKETCODER SSH KEY SYNC
# This script copies authorized public keys from the shared volume
# (populated by the relay) to the worker's authorized_keys file.

SOURCE_FILE=${SSH_KEYS_FILE:-"/ssh_keys/authorized_keys"}
DEST_FILE="/home/worker/.ssh/authorized_keys"

echo "🔄 [SyncKeys] Syncing keys from $SOURCE_FILE..."

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "⚠️ [SyncKeys] Source file not found, skipping sync"
    exit 0
fi

# Read keys from shared volume
KEYS=$(cat "$SOURCE_FILE")

if [ ! -z "$KEYS" ]; then
    mkdir -p /home/worker/.ssh
    echo "$KEYS" > "$DEST_FILE"
    chmod 700 /home/worker/.ssh
    chmod 600 "$DEST_FILE"
    chown -R worker:worker /home/worker/.ssh
    echo "✅ [SyncKeys] Successfully updated $(echo "$KEYS" | wc -l) keys."
else
    echo "⚠️ [SyncKeys] No keys found in source file."
fi
