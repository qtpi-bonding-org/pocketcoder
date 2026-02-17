#!/bin/bash
# new_tests/helpers/inspect_cao.sh
# Queries CAO SQLite database via docker exec and displays terminals table.
# Usage: ./helpers/inspect_cao.sh

set -e

DB_PATH="/root/.aws/cli-agent-orchestrator/db/cli-agent-orchestrator.db"

echo "🗄️  CAO Database - Terminals Table"
echo "--------------------------------------------------------------------------------"
echo "Fields: delegating_agent_id, tmux_session, tmux_window_id"
echo "--------------------------------------------------------------------------------"

docker exec pocketcoder-sandbox python3 -c "
import sqlite3, json, sys
conn = sqlite3.connect('$DB_PATH')
conn.row_factory = sqlite3.Row
cursor = conn.cursor()
# Note: external_session_id in DB maps to delegating_agent_id in API
cursor.execute('SELECT id, tmux_session, tmux_window, tmux_window_id, agent_profile, provider, external_session_id as delegating_agent_id FROM terminals')
rows = [dict(row) for row in cursor.fetchall()]
print(json.dumps(rows, indent=2))
"

echo "--------------------------------------------------------------------------------"