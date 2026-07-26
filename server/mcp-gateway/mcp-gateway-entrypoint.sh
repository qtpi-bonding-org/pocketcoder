#!/bin/sh
set -e

echo "Initializing MCP catalog..."
docker mcp catalog init

echo "Starting MCP Gateway with args: $@"
exec docker mcp gateway run "$@"
