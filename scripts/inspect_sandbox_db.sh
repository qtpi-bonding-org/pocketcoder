#!/bin/bash
# scripts/inspect_sandbox_db.sh
# Dumps the CAO SQLite database from the sandbox container.

set -e

DB_PATH="/root/.aws/cli-agent-orchestrator/db/cli-agent-orchestrator.db"

echo "🗄️  Dumping CAO Database Tables (Terminals)"
echo "--------------------------------------------------------------------------------"

echo "--- TERMINALS ---"
docker exec pocketcoder-sandbox python3 -c "
import sqlite3, json
conn = sqlite3.connect('$DB_PATH')
conn.row_factory = sqlite3.Row
cursor = conn.cursor()
# Note: session_name in API mapping is tmux_session in DB
cursor.execute('SELECT id, tmux_session, tmux_window, agent_profile, provider, external_session_id FROM terminals')
rows = [dict(row) for row in cursor.fetchall()]
print(json.dumps(rows, indent=2))
"
echo "--------------------------------------------------------------------------------"
