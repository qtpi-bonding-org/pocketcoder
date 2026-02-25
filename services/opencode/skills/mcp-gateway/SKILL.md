---
name: mcp-gateway
description: How to discover, request, and use MCP servers via the Docker MCP Gateway with Dynamic MCP.
---

# SKILL: MCP Gateway Integration (Dynamic MCP)

When a task requires external tools (databases, APIs, services), use the MCP Gateway workflow.

## How It Works

PocketCoder uses Dynamic MCP. The gateway exposes primordial tools
(`mcp-find`, `mcp-add`, `mcp-remove`) to connected clients. Subagents
discover and add servers on-demand from an approved catalog. The gateway
spins up containers automatically when `mcp-add` is called.

The catalog (`docker-mcp.yaml`) gates what can be installed. PocketBase
writes it from the database. Only user-approved servers appear in the catalog.

## Discovery

1. Use the `mcp_status` tool to check what's already approved in the catalog.
2. Use the `mcp_catalog` tool to browse the full Docker MCP Catalog.

## Requesting

3. If the needed server isn't approved, use `mcp_request` with the server name and reason. 
   - **Note**: This tool automatically researches the required image and secrets before submitting.
4. Tell the user you've submitted the request and are waiting for approval.
5. When the user approves the record in PocketBase (and provides any required secrets), the catalog updates and the gateway restarts.

## Delegation (Dynamic MCP)

6. Spawn a subagent via `cao_handoff` or `cao_assign`.
7. The subagent connects to the gateway SSE at `http://mcp-gateway:8811/sse`.
8. The subagent uses `mcp-find` to discover available servers from the catalog.
9. The subagent uses `mcp-add` to add the server — the gateway spins up the container.
10. The subagent uses the MCP tools provided by the server.
11. You (Poco) do NOT use MCP tools directly. Only subagents in the sandbox can.

## Important

- Never request a server that's already approved (check `mcp_status` first).
- Always explain to the user what server you need and why.
- MCP tools run in isolated containers managed by the gateway.
- Servers added via `mcp-add` are session-scoped — they don't persist across sessions.
- The catalog only contains user-approved servers. Subagents cannot add servers outside it.
