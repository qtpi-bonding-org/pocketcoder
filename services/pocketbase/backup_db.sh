#!/bin/sh
# PocketCoder: Automatic SQLite Backup Script
# Runs periodically to backup PocketBase database to external volume

set -e

DB_PATH="/app/pb_data/data.db"
BACKUP_DIR="/app/pb_backups"
BACKUP_FILE="$BACKUP_DIR/data.db"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Check if main database exists
if [ ! -f "$DB_PATH" ]; then
    exit 0
fi

# Backup using SQLite's backup command (atomic and safe)
sqlite3 "$DB_PATH" ".backup '$BACKUP_FILE.tmp'"

# Atomic move
mv "$BACKUP_FILE.tmp" "$BACKUP_FILE"

# Copy WAL and SHM files
cp "$DB_PATH-wal" "$BACKUP_FILE-wal" 2>/dev/null || true
cp "$DB_PATH-shm" "$BACKUP_FILE-shm" 2>/dev/null || true

echo "✅ [Backup] Database backed up"
