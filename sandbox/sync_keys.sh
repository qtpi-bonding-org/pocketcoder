#!/bin/bash

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
