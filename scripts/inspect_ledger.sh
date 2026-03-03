#!/bin/bash
# scripts/inspect_ledger.sh
# Systematically inspects the state of the Sovereign Ledger (PocketBase).

set -e

if [ ! -f .env ]; then echo "❌ .env not found"; exit 1; fi
export $(grep -v '^#' .env | xargs)
PB_URL="http://127.0.0.1:8090"

# 1. Authenticate
TOKEN=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$POCKETBASE_ADMIN_EMAIL\",\"password\":\"$POCKETBASE_ADMIN_PASSWORD\"}" | jq -r '.token')

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then echo "❌ Auth Failed"; exit 1; fi

echo "📜 --- SOVEREIGN LEDGER INSPECTION ---"
date

# 2. Latest Chat
echo -e "\n💬 LATEST CHAT:"
curl -s -X GET "$PB_URL/api/collections/chats/records?sort=-created&limit=1" \
    -H "Authorization: $TOKEN" | jq -r '.items[0] | "ID: \(.id)\nTitle: \(.title)\nCreated: \(.created)"'

# 3. Active Permissions (Intents)
echo -e "\n🛡️  PENDING/AUTHORIZING INTENTS (PERMISSIONS):"
curl -s -X GET "$PB_URL/api/collections/permissions/records?filter=(status!='completed')&sort=-created&limit=5" \
    -H "Authorization: $TOKEN" | jq -r '.items[] | "[\(.status)] ID: \(.id) | Label: \(.label // "N/A")"'

# 4. Agents & Sandbox Agents
echo -e "\n🤖 REGISTERED AGENTS:"
curl -s -X GET "$PB_URL/api/collections/ai_agents/records" \
    -H "Authorization: $TOKEN" | jq -r '.items[] | "[\(.name)] ID: \(.id) | Provider: \(.provider // "standard")"'

echo -e "\n--------------------------------------------------------------------------------"
