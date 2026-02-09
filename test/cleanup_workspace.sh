#!/bin/bash
# test/cleanup_workspace.sh
# Removes common test files from the sandbox workspace

echo "🧹 Cleaning up sandbox workspace..."
docker exec pocketcoder-opencode rm -f /workspace/automated_test.txt /workspace/pocketcoder_test.md /workspace/intercept_me.txt /workspace/test.md
echo "✅ Cleanup complete."
