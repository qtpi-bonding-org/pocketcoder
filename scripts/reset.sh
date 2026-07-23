#!/bin/bash
# reset.sh - Restores PocketCoder to a completely clean, pre-deployment state.

set -e

echo "🧹 Initiating PocketCoder Reset..."

# 1. Stop all services and wipe volumes
echo "🚨 Destroying containers and wiping persistent volumes..."
docker compose down -v

# 2. Reset MCP Gateway configuration state
MCP_DIR="services/mcp-gateway/config"
echo "🔌 Cleaning MCP Gateway state files..."
rm -f "$MCP_DIR/docker-mcp.yaml"
rm -f "$MCP_DIR/mcp.env"
# The gateway tracks state dynamically in these files, they must be purged
rm -f "$MCP_DIR/registry.yaml" \
      "$MCP_DIR/tools.yaml" \
      "$MCP_DIR/config.yaml" \
      "$MCP_DIR/catalog.json"

# 3. Wipe deploy secrets and keys
if [ -f .env ]; then
    grep "API" .env > .env.temp || true
    rm -f .env
    mv .env.temp .env
fi
rm -rf .ssh_keys

echo "✅ PocketCoder is now in a clean state."
echo "   Run './deploy.sh' to bootstrap a fresh instance."
