#!/bin/bash
# scripts/export_schema.sh
# PocketCoder Schema Export utility.
# Syncs the backend PocketBase schema to the Flutter assets.

set -e

# Configuration
OUTPUT_FILE="client/assets/pb_schema.json"
PB_URL="http://127.0.0.1:8090"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTH_HELPER="$SCRIPT_DIR/pb_auth.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Schema export requires superuser permissions
AUTH_FLAGS="--superuser"

echo -e "${BLUE}Authenticating with PocketBase using $AUTH_FLAGS...${NC}"
TOKEN=$($AUTH_HELPER $AUTH_FLAGS)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}Failed to obtain auth token.${NC}"
    exit 1
fi

echo -e "${BLUE}Fetching collection schema...${NC}"
# We fetch 100 collections max (plenty for PocketCoder)
curl -s "$PB_URL/api/collections?perPage=100" \
    -H "Authorization: $TOKEN" > "$OUTPUT_FILE"

if [ -s "$OUTPUT_FILE" ]; then
    # Verify it is valid JSON
    if jq empty "$OUTPUT_FILE" >/dev/null 2>&1; then
        COLCOUNT=$(jq '.totalItems' "$OUTPUT_FILE")
        echo -e "${GREEN}✅ Successfully exported $COLCOUNT collections to $OUTPUT_FILE${NC}"
    else
        echo -e "${RED}Error: Exported file contains invalid JSON.${NC}"
        cat "$OUTPUT_FILE"
        exit 1
    fi
else
    echo -e "${RED}Error: Failed to fetch schema (empty response).${NC}"
    exit 1
fi
