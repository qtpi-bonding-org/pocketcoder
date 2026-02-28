#!/bin/bash
# inspect_tmux_window.sh - Capture and print the last N lines of a tmux window inside the sandbox.
# Usage: ./inspect_tmux_window.sh [window_id] [lines]
# Example: ./inspect_tmux_window.sh 2a7cbc36:0 200
# If no window given, lists all windows first.

CONTAINER="pocketcoder-sandbox"
WINDOW="${1}"
LINES="${2:-150}"

if [ -z "$WINDOW" ]; then
  echo "Usage: $0 <session:window> [lines]"
  echo ""
  echo "Available windows:"
  docker exec "$CONTAINER" tmux -S/tmp/tmux/pocketcoder list-windows -a 2>/dev/null || echo "(no tmux sessions found)"
  exit 0
fi

echo "======================================================"
echo "  📟 TMUX WINDOW: $WINDOW (last $LINES lines)"
echo "  Container: $CONTAINER"
echo "  Time: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================"
echo ""

docker exec "$CONTAINER" tmux -S/tmp/tmux/pocketcoder capture-pane -t "$WINDOW" -p -S "-${LINES}" 2>/dev/null \
  || echo "Error: could not capture pane. Is the window ID correct?"
