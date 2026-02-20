#!/usr/bin/env bash

# PocketCoder Observability Script
# Captures full output from a specific tmux window.
# Usage: ./tmux_capture.sh <session_name> <window_name>

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <session_name> <window_name>"
  echo "Example: $0 pocketcoder poco:terminal"
  exit 1
fi

SESSION="$1"
WINDOW="$2"
CONTAINER="pocketcoder-sandbox"

echo "=== Capturing Tmux Window: $SESSION:$WINDOW ==="
docker exec -it "$CONTAINER" tmux -S /tmp/tmux/pocketcoder capture-pane -t "${SESSION}:${WINDOW}" -p -S -
