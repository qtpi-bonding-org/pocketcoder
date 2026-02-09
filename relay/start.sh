#!/bin/bash
set -e

# Start SSH key sync service in background
echo "🚀 Starting SSH key sync service..."
node /app/sync_ssh_keys.mjs &
SSH_SYNC_PID=$!

# Give it a moment to start
sleep 2

# Check if it's still running
if ! kill -0 $SSH_SYNC_PID 2>/dev/null; then
    echo "❌ SSH sync service failed to start"
    exit 1
fi

echo "✅ SSH sync service started (PID: $SSH_SYNC_PID)"

# Start chat relay in foreground
echo "🚀 Starting chat relay..."
exec node /app/chat_relay.mjs
