#!/bin/sh
# PocketCoder: Automatic SQLite Backup Script
# Runs periodically to backup PocketBase database to external volume

set -e

DB_PATH="/app/pb_data/data.db"
BACKUP_DIR="/app/pb_backups"
BACKUP_FILE="$BACKUP_DIR/data.db"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

if [ ! -f "$DB_PATH" ]; then
    exit 0
fi

# Backup using SQLite's backup command (atomic and safe)
sqlite3 "$DB_PATH" ".backup '$BACKUP_FILE.tmp'"

# Rotate: keep one previous backup as safety net
if [ -f "$BACKUP_FILE" ]; then
    mv "$BACKUP_FILE" "$BACKUP_FILE.prev"
    [ -f "$BACKUP_FILE-wal" ] && mv "$BACKUP_FILE-wal" "$BACKUP_FILE.prev-wal"
    [ -f "$BACKUP_FILE-shm" ] && mv "$BACKUP_FILE-shm" "$BACKUP_FILE.prev-shm"
fi

# Atomic move new backup into place
mv "$BACKUP_FILE.tmp" "$BACKUP_FILE"

# Copy WAL and SHM files
[ -f "$DB_PATH-wal" ] && cp "$DB_PATH-wal" "$BACKUP_FILE-wal"
[ -f "$DB_PATH-shm" ] && cp "$DB_PATH-shm" "$BACKUP_FILE-shm"

echo "✅ [Backup] Database backed up"
