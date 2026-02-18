---
name: mcp-gateway
description: How to discover, request, and use MCP servers via the Docker MCP Gateway.
---

# SKILL: MCP Gateway Integration

When a task requires external tools (databases, APIs, services), use the MCP Gateway workflow.

## Discovery
1. Use the `mcp_status` tool to check what's already enabled.
2. Use the `mcp_catalog` tool to browse available servers. Search by keyword.

## Requesting
3. If the needed server isn't enabled, use `mcp_request` with the server name and reason.
4. Tell the user you've submitted the request and are waiting for approval.
5. When PocketBase notifies you the server is ready, proceed to delegation.

## Delegation
6. Spawn a subagent via `cao_handoff` or `cao_assign`.
7. The subagent profile should include the MCP gateway connection.
8. The subagent connects to `http://mcp-gateway:8811/sse` and uses the MCP tools.
9. You (Poco) do NOT use MCP tools directly. Only subagents in the sandbox can.

## Important
- Never request a server that's already enabled (check `mcp_status` first).
- Always explain to the user what server you need and why.
- MCP tools run in isolated containers managed by the gateway.