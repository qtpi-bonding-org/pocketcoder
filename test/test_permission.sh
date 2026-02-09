#!/bin/bash
# test_permission.sh

OPENCODE_URL="http://127.0.0.1:3000"

echo "🧪 Testing Gatekeeper Permissions..."

# 1. Create Session
echo "1. Creating Session..."
SESSION_RES=$(curl -v -s -X POST "$OPENCODE_URL/session" \
    -H "Content-Type: application/json" \
    -d '{ "directory": "/workspace" }')

echo "Session Response: $SESSION_RES"

SESSION_ID=$(echo "$SESSION_RES" | grep -o '"id":"[^"]*"' | grep -o 'ses_[a-zA-Z0-9]*')
if [ -z "$SESSION_ID" ]; then
    echo "❌ Failed to get Session ID"
    exit 1
fi
echo "✅ Session ID: $SESSION_ID"

# 2. Send Tool Prompt
echo "2. Sending 'Create file' prompt (Should hang or request permission)..."
PROMPT_RES=$(curl -s -X POST "$OPENCODE_URL/session/$SESSION_ID/message" \
    -H "Content-Type: application/json" \
    -d '{
        "parts": [
            { "type": "text", "text": "Create a file named intercept_me.txt with content: unauthorized" }
        ]
    }')

echo "Prompt Result:"
echo "$PROMPT_RES"
