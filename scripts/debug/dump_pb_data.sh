#!/bin/bash

# Script to print out chats, messages, and permissions from PocketBase SQLite database

echo "================ CHATS ================"
docker exec pocketcoder-pocketbase sqlite3 -header -column pb_data/data.db "SELECT * FROM chats;"

echo -e "\n================ MESSAGES (Last 50) ================"
docker exec pocketcoder-pocketbase sqlite3 -header -column pb_data/data.db "SELECT * FROM messages ORDER BY created DESC LIMIT 50;"

echo -e "\n================ PERMISSIONS ================"
docker exec pocketcoder-pocketbase sqlite3 -header -column pb_data/data.db "SELECT * FROM permissions ORDER BY created DESC;"
