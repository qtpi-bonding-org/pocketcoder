#!/bin/bash
# new_tests/helpers/auth.sh
# Authentication helper for PocketBase API testing
# Reads credentials from .env and exports USER_TOKEN
# Usage: source helpers/auth.sh

set -e

PB_URL="http://127.0.0.1:8090"

# Load .env file to get credentials
# Try current directory first, then parent directory
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
elif [ -f ../.env ]; then
    export $(grep -v '^#' ../.env | xargs)
fi

# Check for --super flag
USE_SUPERUSER=false
for arg in "$@"; do
    if [ "$arg" = "--super" ]; then
        USE_SUPERUSER=true
    fi
done

# Select credentials based on flag
if [ "$USE_SUPERUSER" = true ]; then
    if [ -z "$POCKETBASE_SUPERUSER_EMAIL" ] || [ -z "$POCKETBASE_SUPERUSER_PASSWORD" ]; then
        echo "❌ Error: Superuser credentials not found in .env" >&2
        return 1 2>/dev/null || exit 1
    fi
    PB_EMAIL="$POCKETBASE_SUPERUSER_EMAIL"
    PB_PASSWORD="$POCKETBASE_SUPERUSER_PASSWORD"
else
    if [ -z "$POCKETBASE_ADMIN_EMAIL" ] || [ -z "$POCKETBASE_ADMIN_PASSWORD" ]; then
        echo "❌ Error: POCKETBASE_ADMIN_EMAIL or POCKETBASE_ADMIN_PASSWORD not found in .env" >&2
        return 1 2>/dev/null || exit 1
    fi
    PB_EMAIL="$POCKETBASE_ADMIN_EMAIL"
    PB_PASSWORD="$POCKETBASE_ADMIN_PASSWORD"
fi

# Authenticate with PocketBase
if [ "$USE_SUPERUSER" = true ]; then
    TOKEN_RES=$(curl -s -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{
            \"identity\": \"$PB_EMAIL\",
            \"password\": \"$PB_PASSWORD\"
        }")
else
    TOKEN_RES=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{
            \"identity\": \"$PB_EMAIL\",
            \"password\": \"$PB_PASSWORD\"
        }")
fi

# Extract token from response
USER_TOKEN=$(echo "$TOKEN_RES" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$USER_TOKEN" ]; then
    echo "❌ Failed to authenticate with PocketBase" >&2
    echo "Response: $TOKEN_RES" >&2
    return 1 2>/dev/null || exit 1
fi

# Export the token for use in test scripts
export USER_TOKEN

echo "✅ Authenticated successfully. USER_TOKEN exported."