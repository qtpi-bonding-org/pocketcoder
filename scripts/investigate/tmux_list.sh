#!/usr/bin/env bash

# PocketCoder Observability Script
# Lists all tmux sessions and windows from the sandbox container.

CONTAINER="pocketcoder-sandbox"

echo "=== Tmux Sessions ==="
docker exec -it "$CONTAINER" tmux -S /tmp/tmux/pocketcoder ls

echo ""
echo "=== Tmux Windows ==="
# Loop through sessions and list windows
SESSIONS=$(docker exec -it "$CONTAINER" tmux -S /tmp/tmux/pocketcoder ls -F "#{session_name}" 2>/dev/null)
for session in $SESSIONS; do
  echo "--- Session: $session ---"
  # Clean \r from session name just in case
  session=$(echo "$session" | tr -d '\r')
  docker exec -it "$CONTAINER" tmux -S /tmp/tmux/pocketcoder list-windows -t "$session"
done
