#!/bin/bash
# sandbox_status.sh - What's running inside the sandbox that docker ps won't tell you:
# tmux sessions (subagent windows) and active CAO terminals.
# Usage: bash scripts/debug/sandbox_status.sh

CONTAINER="pocketcoder-sandbox"

echo "======================================================"
echo "  🖥️  SANDBOX STATUS: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================"
echo ""

# 1. Tmux sessions — each window = one assigned agent
echo "─── TMUX SESSIONS / SUBAGENT WINDOWS ───────────────"
docker exec "$CONTAINER" tmux -S/tmp/tmux/pocketcoder list-windows -a 2>/dev/null \
  || echo "  (no tmux sessions found)"
echo ""

# 2. Active CAO sessions (assigned terminals with metadata)
echo "─── CAO SESSIONS (ASSIGNED TERMINALS) ──────────────"
RAW=$(docker exec "$CONTAINER" curl -s http://localhost:3001/sessions 2>/dev/null)
if [ -n "$RAW" ] && [ "$RAW" != "Not Found" ]; then
  echo "$RAW" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    items = d if isinstance(d, list) else d.get('sessions', d.get('items', []))
    if not items:
        print('  (no active sessions)')
    for s in items:
        print(f'  terminal_id={s.get(\"id\",\"?\")} | session={s.get(\"session_name\",\"?\")} | agent={s.get(\"agent_profile\",\"?\")} | status={s.get(\"status\",\"?\")} | delegator={s.get(\"delegating_agent_id\",\"-\")}')
except:
    print(sys.stdin.read())
" 2>/dev/null || echo "$RAW"
else
  echo "  (no active sessions)"
fi
echo ""
