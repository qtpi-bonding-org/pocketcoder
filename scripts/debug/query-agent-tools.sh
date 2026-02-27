#!/bin/bash
# Asks the developer agent in the Sandbox to list all its available tools.
# This proves what the agent actually sees after correctly connecting to the MCP Gateway.
# The --format json makes it machine-friendly, but we extract the text block for readability if jq is available.

echo "Querying Sandbox Agent for tools..."
docker compose exec -T sandbox opencode run --agent developer --format json "Hello. Please list the exact names of all the MCP tools you currently have available. Only list them, do not use them, and stop right after." | grep '^{"type":"text"' | sed 's/.*"text":"//' | sed 's/","time".*//' | sed 's/\\n/\n/g'
