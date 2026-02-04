#!/bin/bash
# 🏰 POCKETCODER DIAGNOSTIC SMOKE TEST

set -e
if [ -f .env ]; then export $(grep -v '^#' .env | xargs); fi

echo "🚀 Starting Diagnostic Smoke Test..."

# 1. Clear previous logs
docker-compose exec -T opencode rm -f /workspace/diag.log

# 2. Trigger with JUST the plugin (No MCP)
echo "🧠 Triggering opencode (Plugin only)..."
docker-compose exec -T -w /workspace opencode /bin/sh -c "OPENCODE_CONFIG_CONTENT='{\"plugin\":[\"file:///pocketcoder-plugin.ts\"]}' TERM=dumb NO_COLOR=1 opencode run 'say hello' --format json > /workspace/diag.log 2>&1 &"

echo "⏳ Waiting 10s..."
sleep 10

echo "🏁 Log Content:"
docker-compose exec -T opencode cat /workspace/diag.log
