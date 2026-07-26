#!/bin/sh
# PocketCoder: Restore from Backup Script
# If main DB is missing/empty but backup exists, archive backup with timestamp

set -e

DB_PATH="/app/pb_data/data.db"
BACKUP_DIR="/app/pb_backups"
BACKUP_FILE="$BACKUP_DIR/data.db"
ARCHIVE_DIR="$BACKUP_DIR/archives"

# Ensure directories exist
mkdir -p "$BACKUP_DIR"
mkdir -p "$ARCHIVE_DIR"

# If no backup exists, nothing to do
if [ ! -f "$BACKUP_FILE" ]; then
    exit 0
fi

# If main DB exists and has data, nothing to do
if [ -f "$DB_PATH" ]; then
    exit 0
fi

# Main DB is missing, backup exists - archive it with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_FILE="$ARCHIVE_DIR/backup_${TIMESTAMP}.db"

echo "📦 [Restore] Archiving backup to: backup_${TIMESTAMP}.db"
cp "$BACKUP_FILE" "$ARCHIVE_FILE"
cp "$BACKUP_FILE-wal" "$ARCHIVE_FILE-wal" 2>/dev/null || true
cp "$BACKUP_FILE-shm" "$ARCHIVE_FILE-shm" 2>/dev/null || true

# Remove backup so new DB can start fresh
rm -f "$BACKUP_FILE" "$BACKUP_FILE-wal" "$BACKUP_FILE-shm"

echo "✅ [Restore] Backup archived, starting fresh"
