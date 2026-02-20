#!/usr/bin/env bash

# PocketCoder Observability Script
# Fetches the latest logs from the CAO agent.
# Usage: ./cao_terminal_logs.sh [lines]

LINES=${1:-100}
CONTAINER="pocketcoder-sandbox"

echo "=== Latest CAO Logs ==="
LATEST_LOG=$(docker exec -t "$CONTAINER" ls -t /root/.aws/cli-agent-orchestrator/logs/ | head -n 1)

if [ -z "$LATEST_LOG" ]; then
  echo "No logs found in CAO logs directory."
  exit 0
fi

docker exec -t "$CONTAINER" tail -n "$LINES" "/root/.aws/cli-agent-orchestrator/logs/$LATEST_LOG"
