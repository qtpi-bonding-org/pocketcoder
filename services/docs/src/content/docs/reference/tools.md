---
title: Tools & Interface Reference
head: []
---

## Update Checker
> Checks the Codeberg repo for new commits/releases.

**Description:** Check for PocketCoder updates from the official Codeberg repository. Shows recent commits on main and any releases. Use this when the user asks about updates, or occasionally to keep them informed.

**Args:**
- `count` — Number of recent commits to show

---

## MCP Catalog Browser
> Lets Poco discover available Docker MCP servers.

**Description:** Browse or search the Docker MCP Catalog to discover available MCP servers. Returns the names and descriptions of all matching servers.

**Args:**
- `query` — Optional search term to filter servers (checks both name and description)

---

## MCP Inspector
> Deep-inspects server tools, config schema, and README from the catalog.

**Description:** Inspect an MCP server's technical details, including its tools, environment variables, and README documentation from the catalog.

**Args:**
- `server_name` — The name of the MCP server to inspect (e.g., 'n8n', 'mysql')
- `mode` — Filter what information to return

---

## MCP Request Tool
> Submits enriched MCP server requests to PocketBase for user approval.

**Description:** Request a new MCP server to be enabled. Automatically researches the technical requirements (image, secrets) from the Docker MCP catalog before submitting.

**Args:**
- `server_name` — Name of the MCP server (e.g., 'n8n', 'mysql')
- `reason` — Why this server is needed for the current task

---

## MCP Status
> Reports which MCP servers are currently live in the gateway.

**Description:** Check which MCP servers are currently enabled in the gateway. Reads the live config.

---

## Session Env Plugin
> Injects session and agent identity into OpenCode shell environments.

---

## Interface Bridge
> Event pump + command pump syncing PocketBase with OpenCode.

---
