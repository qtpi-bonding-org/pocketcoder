#!/bin/sh
# PocketCoder: Restore from Backup Script
# If the main DB is missing but a backup exists, restore the backup before
# PocketBase starts. The backup is a SQLite online-backup copy, so it is a
# complete database and does not need the source WAL/SHM files.

set -e

DB_PATH="/app/pb_data/data.db"
BACKUP_DIR="/app/pb_backups"
BACKUP_FILE="$BACKUP_DIR/data.db"

# Ensure directories exist
mkdir -p "$BACKUP_DIR"

# If no backup exists, nothing to do
if [ ! -f "$BACKUP_FILE" ]; then
    exit 0
fi

# If main DB exists, never overwrite it automatically.
if [ -f "$DB_PATH" ]; then
    exit 0
fi

echo "📦 [Restore] Restoring database from backup"
install -m 600 "$BACKUP_FILE" "$DB_PATH"

echo "✅ [Restore] Database restored from backup"
