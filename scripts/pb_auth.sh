#!/bin/bash
# scripts/pb_auth.sh
# PocketCoder Authentication Helper script.
# Fetches a PocketBase auth token based on the requested role.

set -e

# Default values
ROLE="admin"
PB_URL="http://127.0.0.1:8090"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --admin       Authenticate as the Admin (default)"
    echo "  --agent       Authenticate as the AI Agent"
    echo "  --superuser   Authenticate as the PocketBase Superuser"
    echo "  --help        Show this help message"
    exit 1
}

# Parse flags
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --admin) ROLE="admin" ;;
        --agent) ROLE="agent" ;;
        --superuser) ROLE="superuser" ;;
        --help) usage ;;
        *) echo -e "${RED}Unknown parameter: $1${NC}"; usage ;;
    esac
    shift
done

# Load environment variables
if [ -f .env ]; then
    # Filter out comments and empty lines, then export
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${RED}Error: .env file not found.${NC}" >&2
    exit 1
fi

# Set identity and collection based on role
case $ROLE in
    "superuser")
        IDENTITY=$POCKETBASE_SUPERUSER_EMAIL
        PASSWORD=$POCKETBASE_SUPERUSER_PASSWORD
        COLLECTION="_superusers"
        ;;
    "admin")
        IDENTITY=$POCKETBASE_ADMIN_EMAIL
        PASSWORD=$POCKETBASE_ADMIN_PASSWORD
        COLLECTION="users"
        ;;
    "agent")
        IDENTITY=$AGENT_EMAIL
        PASSWORD=$AGENT_PASSWORD
        COLLECTION="users"
        ;;
esac

if [ -z "$IDENTITY" ] || [ -z "$PASSWORD" ]; then
    echo -e "${RED}Error: Credentials for $ROLE not found in .env${NC}" >&2
    exit 1
fi

# Fetch the token
TOKEN_RES=$(curl -s -X POST "$PB_URL/api/collections/$COLLECTION/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{
        \"identity\": \"$IDENTITY\",
        \"password\": \"$PASSWORD\"
    }")

TOKEN=$(echo "$TOKEN_RES" | jq -r '.token // empty')

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
    echo -e "${RED}Error: Authentication failed for $ROLE${NC}" >&2
    echo "$TOKEN_RES" | jq . >&2
    exit 1
fi

# Output only the token to stdout
echo "$TOKEN"
