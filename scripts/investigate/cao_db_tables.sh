#!/usr/bin/env bash

# PocketCoder Observability Script
# Lists all tables in the CAO SQLite database.

CONTAINER="pocketcoder-sandbox"
DB_PATH="/root/.aws/cli-agent-orchestrator/db/cli-agent-orchestrator.db"

echo "=== CAO Database Tables ==="
docker exec -it "$CONTAINER" uv run --directory /app/cao python -c "import sqlite3; conn = sqlite3.connect('$DB_PATH'); print('\n'.join([r[0] for r in conn.execute('SELECT name FROM sqlite_master WHERE type=\'table\';').fetchall()]))"
