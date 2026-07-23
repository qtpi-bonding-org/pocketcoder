#!/bin/bash
# demo-reset.sh - Restores PocketCoder to a clean state for demo purposes.
# Preserves n8n data (workflows, credentials, account) so you don't have to sign up again.

set -e

echo "🧹 Initiating PocketCoder Demo Reset (n8n data preserved)..."

# 1. Stop all containers WITHOUT wiping volumes (no -v flag)
echo "🛑 Stopping containers..."
docker compose down

# 2. Selectively delete all volumes EXCEPT n8n_data
echo "🗑️  Wiping non-n8n volumes..."
docker volume rm -f \
  pocketcoder_pb_data \
  pocketcoder_pocketcoder-logs \
  pocketcoder_opencode_workspace \
  pocketcoder_opencode_data \
  pocketcoder_cao_db \
  pocketcoder_shell_bridge \
  pocketcoder_ntfy-cache \
  pocketcoder_ntfy-auth

# 3. Reset MCP Gateway configuration state
MCP_DIR="services/mcp-gateway/config"
echo "🔌 Cleaning MCP Gateway state files..."
rm -f "$MCP_DIR/docker-mcp.yaml" \
      "$MCP_DIR/mcp.env" \
      "$MCP_DIR/registry.yaml" \
      "$MCP_DIR/tools.yaml" \
      "$MCP_DIR/config.yaml" \
      "$MCP_DIR/catalog.json"

# 4. Wipe deploy secrets and keys (keep API keys)
if [ -f .env ]; then
    grep "API" .env > .env.temp || true
    rm -f .env
    mv .env.temp .env
fi
rm -rf .ssh_keys

echo ""
echo "✅ Demo reset complete. n8n data (workflows, credentials, account) preserved."
echo "   Run './deploy.sh' to bootstrap a fresh PocketBase instance."
