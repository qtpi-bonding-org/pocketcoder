#!/bin/bash
# export_sandbox_session.sh - Export an OpenCode session from INSIDE the sandbox container.
# Useful when a developer subagent fails — its session lives in the sandbox, not in the opencode container.
# Usage: ./export_sandbox_session.sh [session_id]
# If no session_id given, lists available sessions.

CONTAINER="pocketcoder-sandbox"
SESSION_ID="${1}"

if [ -z "$SESSION_ID" ]; then
  echo "No session ID provided. Listing available sessions in sandbox:"
  echo ""
  docker exec "$CONTAINER" opencode sessions 2>/dev/null || echo "(could not list sessions)"
  exit 0
fi

echo "Exporting sandbox session: $SESSION_ID"
echo ""

RAW=$(docker exec "$CONTAINER" opencode export "$SESSION_ID" 2>/dev/null)

if [ -z "$RAW" ]; then
  echo "Error: no output returned. Is the session ID correct?"
  exit 1
fi

# Pretty-print with python if available, otherwise raw
echo "$RAW" | python3 -c "
import sys, json

lines = sys.stdin.read().splitlines()
j = next((i for i,l in enumerate(lines) if l.strip().startswith('{')), 0)
try:
    data = json.loads('\n'.join(lines[j:]))
except Exception as e:
    print('\n'.join(lines))
    exit(0)

info = data.get('info', {})
print(f'Session: {info.get(\"id\")} | slug: {info.get(\"slug\")} | title: {info.get(\"title\")}')
print(f'Version: {info.get(\"version\")} | dir: {info.get(\"directory\")}')
print()

for m in data.get('messages', []):
    mi = m.get('info', {})
    print(f'--- {mi.get(\"role\",\"?\").upper()} [{mi.get(\"id\",\"?\")}] ---')
    for p in m.get('parts', []):
        t = p.get('type','?')
        if t == 'text':
            print(f'  [text] {p.get(\"text\",\"\")[:500]}')
        elif t == 'tool':
            st = p.get('state', {})
            status = st.get('status','?')
            print(f'  [tool:{p.get(\"tool\",\"?\")}] status={status}')
            print(f'    input:  {json.dumps(st.get(\"input\",{}))[:300]}')
            if st.get('output'): print(f'    output: {str(st[\"output\"])[:400]}')
            if st.get('error'):  print(f'    ERROR:  {str(st[\"error\"])[:400]}')
        elif t == 'error':
            print(f'  [PART ERROR] {json.dumps(p)[:400]}')
        elif t in ('step-start', 'step-finish'):
            st = p
            reason = st.get('reason','')
            print(f'  [{t}] reason={reason}')
    print()
" 2>/dev/null || echo "$RAW"
