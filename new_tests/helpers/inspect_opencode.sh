#!/bin/bash
# new_tests/helpers/inspect_opencode.sh
# Checks OpenCode session status via GET /session/{session_id} endpoint.
# Usage: ./helpers/inspect_opencode.sh <session_id>

set -e

OPENCODE_URL="${OPENCODE_URL:-http://localhost:3000}"
SESSION_ID=$1

if [ -z "$SESSION_ID" ]; then
    echo "Usage: $0 <session_id>"
    exit 1
fi

echo "🔍 OpenCode Session Status"
echo "--------------------------------------------------------------------------------"

RESPONSE=$(curl -s -w "\n%{http_code}" "$OPENCODE_URL/session/$SESSION_ID")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "Session ID: $SESSION_ID"
    echo "Status: ACTIVE"
    echo ""
    echo "Session Details:"
    echo "$BODY" | jq '.'
else
    echo "Session ID: $SESSION_ID"
    echo "Status: NOT FOUND (HTTP $HTTP_CODE)"
    echo ""
    echo "Response:"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
fi

echo "--------------------------------------------------------------------------------"