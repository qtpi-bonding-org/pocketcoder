#!/bin/bash
set -e

# Create tmux session with socket at /tmp/tmux/pocketcoder
tmux -S /tmp/tmux/pocketcoder new-session -d -s pocketcoder_session -n main
chmod 777 /tmp/tmux/pocketcoder

# Start the Rust proxy server in the background
/app/pocketcoder server --port 3001 &

# Wait for OpenCode sshd to be reachable, then create the Poco window
echo "Waiting for OpenCode sshd to be ready..."
# Check if SSH port is open using timeout and nc (BusyBox compatible)
MAX_RETRIES=60
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if timeout 2 sh -c 'nc opencode 2222 </dev/null' 2>/dev/null; then
        echo "OpenCode sshd is ready!"
        break
    fi
    echo "OpenCode sshd not ready, retrying in 2 seconds... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "ERROR: OpenCode sshd did not become ready after $MAX_RETRIES attempts"
    exit 1
fi
echo "OpenCode sshd is ready. Creating Poco window..."

# Create the Poco window that SSH-bridges into the Attach_TUI
tmux -S /tmp/tmux/pocketcoder new-window \
    -t pocketcoder_session -n poco \
    "ssh -t -o StrictHostKeyChecking=no -i /ssh_keys/id_rsa poco@opencode -p 2222"

echo "Poco window created. Starting health watchdog..."

# Run pane health watchdog - ensure Poco window always exists
while true; do
    if ! tmux -S /tmp/tmux/pocketcoder list-windows -t pocketcoder_session \
         | grep -q "poco"; then
        echo "Poco window missing, recreating..."
        tmux -S /tmp/tmux/pocketcoder new-window \
            -t pocketcoder_session -n poco \
            "ssh -t -o StrictHostKeyChecking=no -i /ssh_keys/id_rsa poco@opencode -p 2222"
    fi
    sleep 10
done