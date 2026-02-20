#!/usr/bin/env bash

# PocketCoder Observability Script
# Queries all rows from a specified table in the CAO SQLite database.
# Usage: ./cao_db_query.sh <table_name>

if [ -z "$1" ]; then
  echo "Usage: $0 <table_name>"
  exit 1
fi

TABLE="$1"
CONTAINER="pocketcoder-sandbox"
DB_PATH="/root/.aws/cli-agent-orchestrator/db/cli-agent-orchestrator.db"

echo "=== Querying Table: $TABLE ==="
docker exec -it "$CONTAINER" uv run --directory /app/cao python -c "
import sqlite3
import json

conn = sqlite3.connect('$DB_PATH')
conn.row_factory = sqlite3.Row
rows = conn.execute('SELECT * FROM $TABLE').fetchall()
res = [dict(ix) for ix in rows]
print(json.dumps(res, indent=2))
"
