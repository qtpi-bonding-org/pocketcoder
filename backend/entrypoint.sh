#!/bin/sh
# backend/entrypoint.sh
# Finalizing the OIC identity and database migrations.

set -e

# 1. Run Migrations
echo "📦 Running database migrations..."
/app/pocketbase migrate up || true

# 2. Provision Superuser (Root)
if [ -n "$POCKETBASE_SUPERUSER_EMAIL" ] && [ -n "$POCKETBASE_SUPERUSER_PASSWORD" ]; then
    echo "🔍 Checking for superuser: $POCKETBASE_SUPERUSER_EMAIL..."
    /app/pocketbase superuser upsert "$POCKETBASE_SUPERUSER_EMAIL" "$POCKETBASE_SUPERUSER_PASSWORD"
    echo "✅ Superuser configured."
fi

# 3. Launch PocketBase
echo "🚀 Starting PocketCoder Sovereign Backend..."
exec "$@"
