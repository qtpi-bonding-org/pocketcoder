# Adding Tools (MCP Servers) to Sub-Agents

This guide explains how to equip your **Sub-Agents** (the "Body") with powerful tools using the Model Context Protocol (MCP).

## Philosophy: Zero-Install & Ephemeral

In PocketCoder, we prioritize **security** and **simplicity**. 
- We **avoid** installing tools permanently into the Docker container.
- We **prefer** ephemeral execution using `uvx` (for Python tools) or `npx` (for Node tools).

This means your agent's tools are defined **declaratively** in its profile and spun up only when needed.

## Quick Start: Adding a Tool

To give an agent a new tool, you simply edit its Markdown definition file in `sandbox/cao/agent_store/`.

### 1. Locate the Agent Definition
Navigate to `sandbox/cao/agent_store/`. You will see files like `senior_engineer.md` or `researcher.md`.

### 2. Add the `mcpServers` Block
Add a YAML frontmatter block (or update the existing one) to include `mcpServers`.

#### Example: Adding PostgreSQL Access (Python)
Use `uvx` to run the standardized `mcp-server-postgres`.

```markdown
---
name: "Database Specialist"
description: "An agent that can safely query the database."
mcpServers:
  postgres:
    command: "uvx"
    args:
      - "mcp-server-postgres"
      - "--local-postgres"  # Or your specific connection string
    env:
      POSTGRES_PASSWORD: "mysecretpassword"
---

You are a database specialist. Use the `postgres` tool to inspect schemas and run read-only queries.
```

#### Example: Adding File System Access (Node)
Use `npx` to run a Node-based MCP server.

```markdown
---
name: "File Manager"
mcpServers:
  filesystem:
    command: "npx"
    args:
      - "-y"
      - "@modelcontextprotocol/server-filesystem"
      - "/sandbox/workspace"
---

You help manage files in the workspace.
```

## How It Works Under the Hood

1.  **Definition**: You define the tool in the Agent's Markdown file.
2.  **Orchestration**: When you run a task with this agent, the **Orchestrator (CAO)** reads this definition.
3.  **Injection**: CAO injects these settings into the `OPENCODE_CONFIG_CONTENT` environment variable.
4.  **Execution**: The `opencode` runtime sees this config and automatically spawns the MCP server using the command you specified (`uvx` or `npx`).
5.  **Connection**: The agent connects to the MCP server over stdio and can now use its tools.

## Supported Runtimes

The Sandbox comes pre-installed with:
- **`uv` / `uvx`**: For running Python-based MCP servers (fast, cached, no virtualenv hassle).
- **`npm` / `npx`**: For running Node.js-based MCP servers.

## Finding MCP Servers

You can find a list of available MCP servers in the [official MCP registry](https://github.com/modelcontextprotocol/servers) or by searching generally for "MCP server".

Common ones include:
- `mcp-server-postgres`: Database interaction
- `mcp-server-git`: Git repository management
- `mcp-server-filesystem`: tailored file access
- `mcp-server-fetch`: Web browsing/fetching capabilities

## Security Note

Because these tools run inside the **Sandbox** container, they are isolated from your host system. However, always be careful when passing secrets (like database passwords) in environment variables.
