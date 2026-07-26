#!/bin/bash

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
set -e

# Pre-backup: export PocketBase data to a backup directory
# Elestio backs up /opt/elestio/backups/ automatically
BACKUP_DIR="/opt/elestio/backups/pocketcoder"
mkdir -p "$BACKUP_DIR"

# Copy PocketBase data volume contents
docker compose cp pocketbase:/app/pb_data "$BACKUP_DIR/pb_data"

# Copy .env for restore
cp .env "$BACKUP_DIR/.env" 2>/dev/null || true
