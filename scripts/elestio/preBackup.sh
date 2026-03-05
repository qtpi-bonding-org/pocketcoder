#!/bin/bash
set -e

# Pre-backup: export PocketBase data to a backup directory
# Elestio backs up /opt/elestio/backups/ automatically
BACKUP_DIR="/opt/elestio/backups/pocketcoder"
mkdir -p "$BACKUP_DIR"

# Copy PocketBase data volume contents
docker compose cp pocketbase:/app/pb_data "$BACKUP_DIR/pb_data"

# Copy .env for restore
cp .env "$BACKUP_DIR/.env" 2>/dev/null || true
