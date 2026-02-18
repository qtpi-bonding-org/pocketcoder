#!/bin/sh
set -e

echo "Initializing MCP catalog..."
docker mcp catalog init

echo "Starting MCP Gateway..."
exec docker mcp gateway run --port 8811 --transport sse --verbose