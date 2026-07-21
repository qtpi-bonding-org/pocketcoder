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

# Script to print out chats, messages, and permissions from PocketBase SQLite database

echo "================ CHATS ================"
docker exec pocketcoder-pocketbase sqlite3 -header -column pb_data/data.db "SELECT * FROM chats;"

echo -e "\n================ MESSAGES (Last 50) ================"
docker exec pocketcoder-pocketbase sqlite3 -header -column pb_data/data.db "SELECT * FROM messages ORDER BY created DESC LIMIT 50;"

echo -e "\n================ PERMISSIONS ================"
docker exec pocketcoder-pocketbase sqlite3 -header -column pb_data/data.db "SELECT * FROM permissions ORDER BY created DESC;"
