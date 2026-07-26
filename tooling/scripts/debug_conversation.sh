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
# tooling/scripts/debug_conversation.sh
# Fetches and formats the full conversation history for the latest or specified chat.

set -e

if [ ! -f .env ]; then
    echo "❌ Error: .env file not found"
    exit 1
fi

export $(grep -v '^#' .env | xargs)
PB_URL="http://127.0.0.1:8090"

# 1. Authenticate
TOKEN=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$POCKETBASE_ADMIN_EMAIL\",\"password\":\"$POCKETBASE_ADMIN_PASSWORD\"}" | jq -r '.token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo "❌ Auth Failed"
    exit 1
fi

# 2. Get Chat ID (latest if not provided)
CHAT_ID=$1
if [ -z "$CHAT_ID" ]; then
    CHAT_ID=$(curl -s -X GET "$PB_URL/api/collections/chats/records?sort=-created&limit=1" \
        -H "Authorization: $TOKEN" | jq -r '.items[0].id')
fi

echo "📖 Conversation for Chat: $CHAT_ID"
echo "--------------------------------------------------------------------------------"

# 3. Fetch and print messages
# Use a separate file for the jq script to avoid shell quoting hell
cat << 'EOF' > /tmp/format_chat.jq
.items[] | "[\(.role | ascii_upcase)] \(.parts[] | select(.type=="text") | .text // "[TOOL_CALL/OTHER]")\n"
EOF

curl -s -X GET "$PB_URL/api/collections/messages/records?filter=(chat='$CHAT_ID')&sort=created&perPage=100" \
    -H "Authorization: $TOKEN" | jq -r -f /tmp/format_chat.jq

echo "--------------------------------------------------------------------------------"
rm /tmp/format_chat.jq
