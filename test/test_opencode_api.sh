#!/bin/bash
# Test OpenCode API directly without plugins

OPENCODE_URL="http://127.0.0.1:3000"

echo "🧪 Testing OpenCode API..."

# 1. Create a session
echo "📝 Creating session..."
SESSION_RES=$(curl -s -X POST "$OPENCODE_URL/session" \
    -H "Content-Type: application/json" \
    -d '{"directory": "/workspace"}')

SESSION_ID=$(echo $SESSION_RES | jq -r '.id')
echo "✅ Session ID: $SESSION_ID"

# 2. Send a prompt
echo "💬 Sending prompt..."
PROMPT_RES=$(curl -s -X POST "$OPENCODE_URL/session/$SESSION_ID/message" \
    -H "Content-Type: application/json" \
    -d '{"parts": [{"type": "text", "text": "Hello! What is 2+2?"}]}')

echo "📨 Response:"
echo $PROMPT_RES | jq .

# 3. Get session messages
echo "📬 Fetching messages..."
MESSAGES=$(curl -s "$OPENCODE_URL/session/$SESSION_ID/message")
echo $MESSAGES | jq .
