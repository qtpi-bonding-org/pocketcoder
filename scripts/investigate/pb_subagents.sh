#!/usr/bin/env bash

# PocketCoder Observability Script
# Lists subagent records from PocketBase database.

CONTAINER="pocketcoder-pocketbase"
DB_PATH="/app/pb_data/data.db"

echo "=== Subagents from PocketBase ==="
docker exec -it "$CONTAINER" sqlite3 -header -column "$DB_PATH" "SELECT * FROM subagents;"
