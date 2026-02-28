#!/bin/bash
# inspect_terminal.sh - Fetch terminal output from the CAO REST API inside the sandbox.
# Usage: ./inspect_terminal.sh [terminal_id] [tail_lines]
# Example: ./inspect_terminal.sh 35347081 100

CONTAINER="pocketcoder-sandbox"
TERMINAL_ID="${1}"
LINES="${2:-100}"

if [ -z "$TERMINAL_ID" ]; then
  echo "Usage: $0 <terminal_id> [tail_lines]"
  echo ""
  echo "To find terminal IDs, run: bash scripts/debug/sandbox_status.sh"
  exit 0
fi

echo "======================================================"
echo "  📋 TERMINAL OUTPUT: $TERMINAL_ID (tail $LINES lines)"
echo "  Time: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================"
echo ""

# Try the CAO HTTP API first
RESULT=$(docker exec "$CONTAINER" curl -s "http://localhost:3001/terminals/${TERMINAL_ID}/output?mode=tail&tail_lines=${LINES}" 2>/dev/null)
if [ -n "$RESULT" ] && [ "$RESULT" != "Not Found" ]; then
  echo "$RESULT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    output = d.get('output', d)
    print(output)
except:
    print(sys.stdin.read())
" 2>/dev/null || echo "$RESULT"
else
  # Fall back: try to find it in tmux
  echo "(CAO API returned nothing — checking tmux fallback)"
  echo ""
  docker exec "$CONTAINER" tmux -S/tmp/tmux/pocketcoder list-windows -a 2>/dev/null || echo "(no tmux sessions)"
fi
