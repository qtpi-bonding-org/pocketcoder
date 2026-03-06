#!/bin/bash
# inspect_terminal.sh - Capture tmux window output from the sandbox.
# Usage: ./inspect_terminal.sh [window_name] [tail_lines]
# Example: ./inspect_terminal.sh poco-terminal 100

CONTAINER="pocketcoder-sandbox"
TMUX_SOCKET="/tmp/tmux/pocketcoder"
TMUX_SESSION="pocketcoder"
WINDOW="${1}"
LINES="${2:-100}"

if [ -z "$WINDOW" ]; then
  echo "Usage: $0 <window_name> [tail_lines]"
  echo ""
  echo "Available windows:"
  docker exec "$CONTAINER" tmux -S "$TMUX_SOCKET" list-windows -t "$TMUX_SESSION" -F '  #{window_index}: #{window_name}' 2>/dev/null || echo "  (sandbox not running)"
  exit 0
fi

echo "======================================================"
echo "  📋 WINDOW OUTPUT: $WINDOW (last $LINES lines)"
echo "  Time: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================"
echo ""

docker exec "$CONTAINER" tmux -S "$TMUX_SOCKET" capture-pane -p -t "${TMUX_SESSION}:${WINDOW}" -S -"${LINES}" 2>/dev/null \
  || echo "(window '$WINDOW' not found — run without args to list available windows)"
