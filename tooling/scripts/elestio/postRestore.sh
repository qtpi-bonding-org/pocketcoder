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
