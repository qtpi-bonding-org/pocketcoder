#!/bin/bash
set -e

# Post-restore: restore PocketBase data and restart the stack
BACKUP_DIR="/opt/elestio/backups/pocketcoder"

if [ -d "$BACKUP_DIR/pb_data" ]; then
  # Start PocketBase briefly to get the container running
  docker compose up -d pocketbase
  sleep 5

  # Restore PocketBase data
  docker compose cp "$BACKUP_DIR/pb_data/." pocketbase:/app/pb_data/

  # Restart to pick up restored data
  docker compose restart pocketbase
fi

# Restore .env if present
if [ -f "$BACKUP_DIR/.env" ]; then
  cp "$BACKUP_DIR/.env" .env
fi

# Start the full stack
docker compose up -d
