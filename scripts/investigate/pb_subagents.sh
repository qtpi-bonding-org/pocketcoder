#!/usr/bin/env bash

# PocketCoder Observability Script
# Lists sandbox agent records from PocketBase database.

CONTAINER="pocketcoder-pocketbase"
DB_PATH="/app/pb_data/data.db"

echo "=== Sandbox Agents from PocketBase ==="
docker exec -it "$CONTAINER" sqlite3 -header -column "$DB_PATH" "SELECT * FROM sandbox_agents;"
