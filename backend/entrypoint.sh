#!/bin/sh
# PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
# Copyright (C) 2026 Qtpi Bonding LLC
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# @pocketcoder-core: Backend Entrypoint. Bootstraps the Go environment and PocketBase.
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
