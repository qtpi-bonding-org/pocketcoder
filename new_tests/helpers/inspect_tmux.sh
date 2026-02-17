#!/bin/bash
# new_tests/helpers/inspect_tmux.sh
# Lists tmux sessions and windows in the sandbox container.
# Usage: ./helpers/inspect_tmux.sh

set -e

echo "🪟 Tmux Sessions and Windows"
echo "--------------------------------------------------------------------------------"

echo "Sessions:"
docker exec pocketcoder-sandbox tmux list-sessions 2>/dev/null || echo "  (no sessions found)"

echo ""
echo "Windows:"
docker exec pocketcoder-sandbox bash -c 'for s in $(tmux list-sessions -F "#S" 2>/dev/null); do echo "  Session $s:"; tmux list-windows -t "$s" -F "    [#{window_id}] #{window_name}"; done' 2>/dev/null || echo "  (no windows found)"

echo "--------------------------------------------------------------------------------"