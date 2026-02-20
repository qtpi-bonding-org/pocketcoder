#!/bin/bash
# PocketCoder: Setup Backup Volume
# Creates the external backup volume that survives docker-compose down -v

set -e

VOLUME_NAME="pocketcoder_pb_backups"

echo "🔍 Checking for backup volume..."

# Check if volume exists
if docker volume inspect "$VOLUME_NAME" > /dev/null 2>&1; then
    echo "✅ Backup volume already exists: $VOLUME_NAME"
    
    # Show volume info
    echo ""
    echo "📊 Volume Information:"
    docker volume inspect "$VOLUME_NAME" --format '  Driver: {{.Driver}}'
    docker volume inspect "$VOLUME_NAME" --format '  Mountpoint: {{.Mountpoint}}'
    docker volume inspect "$VOLUME_NAME" --format '  Created: {{.CreatedAt}}'
    
    # Check if there are any backups
    echo ""
    echo "📦 Checking for existing backups..."
    docker run --rm -v "$VOLUME_NAME:/backups" alpine sh -c '
        if [ -f /backups/data.db ]; then
            SIZE=$(stat -c%s /backups/data.db 2>/dev/null || echo "0")
            echo "  ✅ Current backup: data.db ($SIZE bytes)"
        else
            echo "  ℹ️  No current backup found"
        fi
        
        ARCHIVE_COUNT=$(ls -1 /backups/archives/backup_*.db 2>/dev/null | wc -l)
        if [ "$ARCHIVE_COUNT" -gt 0 ]; then
            echo "  📚 Archived backups: $ARCHIVE_COUNT"
            echo ""
            echo "  Recent archives:"
            ls -lh /backups/archives/backup_*.db 2>/dev/null | tail -5 | awk "{print \"    \" \$9 \" (\" \$5 \")\"}"
        else
            echo "  ℹ️  No archived backups found"
        fi
    '
else
    echo "📦 Creating backup volume: $VOLUME_NAME"
    docker volume create "$VOLUME_NAME"
    echo "✅ Backup volume created successfully"
fi

echo ""
echo "🎯 Backup volume is ready!"
echo ""
echo "ℹ️  This volume will:"
echo "   • Survive 'docker-compose down -v'"
echo "   • Store current backup: /backups/data.db"
echo "   • Archive old backups: /backups/archives/backup_YYYYMMDD_HHMMSS.db"
echo "   • Keep last 10 archives automatically"
echo ""
echo "💡 To manually inspect backups:"
echo "   docker run --rm -v $VOLUME_NAME:/backups alpine ls -lh /backups"
echo ""
echo "💡 To manually backup now:"
echo "   docker exec pocketcoder-pocketbase /app/backup_db.sh"
echo ""
echo "💡 To restore from a specific archive:"
echo "   docker run --rm -v $VOLUME_NAME:/backups alpine cp /backups/archives/backup_YYYYMMDD_HHMMSS.db /backups/data.db"
echo "   docker-compose restart pocketbase"
