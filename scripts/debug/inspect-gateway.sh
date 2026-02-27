#!/bin/bash
# Inspects the n8n tools directly at the MCP Gateway level.
# This confirms the Gateway is successfully talking to the n8n application.

echo "Inspecting n8n server from the MCP Gateway..."
docker compose exec -T mcp-gateway docker mcp server inspect n8n | jq '.tools[].name'
