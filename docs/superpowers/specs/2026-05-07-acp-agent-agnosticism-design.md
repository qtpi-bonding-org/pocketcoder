# ACP Agent Agnosticism Design

**Date:** 2026-05-07  
**Status:** Draft  
**Scope:** Replace OpenCode-specific interface wiring with ACP so any ACP-compliant agent CLI can serve as Poco (the main agent)

---

## Problem

PocketCoder is locked to OpenCode at two levels:

1. `services/interface` uses `@opencode-ai/sdk` — a proprietary REST+SSE API specific to OpenCode
2. `services/opencode` (the Poco container) is hardcoded to OpenCode 1.2.8

This means users must use OpenCode regardless of preference, and cannot use subscription-based CLIs (e.g. Claude Code via Anthropic Max) — only API-key access is available through OpenCode.

---

## Goal

Make Poco swappable. Any ACP-compliant agent CLI can be configured as the main agent. Users can run Claude Code (subscription), OpenCode (API), Gemini CLI, Codex, or any future ACP agent.

---

## Background: ACP

ACP (Agent Client Protocol) is an open standard created by Zed Industries, now adopted by JetBrains, Google, GitHub, and 25+ agents. It defines a JSON-RPC 2.0 bidirectional protocol between an editor/client and an agent.

- **Client** (`ClientSideConnection`) — owns execution: files, terminals, permissions
- **Agent** (`AgentSideConnection`) — reasons and requests; cannot execute directly

ACP enforces that the agent can only *request* things from the client. The client decides whether and how to fulfil each request. This maps cleanly onto PocketCoder's isolation model: Poco reasons, sandbox executes.

Transport: WebSocket or HTTP for inter-container communication (stdio for local subprocesses only).

SDK: `@agentclientprotocol/sdk` v0.21.0 — already cloned at `.independent_repos/typescript-sdk`.

---

## Architecture

### Strict data flow (unchanged)

```
Human → PocketBase → Interface → Poco → Sandbox
```

### With ACP

```
Human (Flutter)
  ↓
PocketBase
  ↓ command pump (PB subscription → ACP prompt)
Interface (ACP ClientSideConnection)
  ↕ ACP over WebSocket
Poco (ACP AgentSideConnection — any compliant agent CLI)
  ↓ MCP (mcpServers config passed in newSession)
Sandbox (poco-agents MCP server — unchanged)
```

Interface is the ACP `ClientSideConnection`. Poco is the ACP `AgentSideConnection`. PocketBase remains the human-facing layer — it is not part of ACP.

---

## Component Changes

### 1. `services/interface` — rewrite as ACP ClientSideConnection

Replace `@opencode-ai/sdk` with `@agentclientprotocol/sdk`. The PocketBase SDK half stays nearly identical.

**Client interface — what Poco calls on Interface (must implement):**

| Method | Action |
|--------|--------|
| `sessionUpdate()` | Write message parts / status to PocketBase |
| `requestPermission()` | Write permission record to PocketBase, wait for user response |
| `readTextFile()` | Proxy to sandbox filesystem |
| `writeTextFile()` | Proxy to sandbox filesystem |
| `createTerminal()` | Proxy to sandbox Rust proxy (pocketcoder-proxy) |
| `terminalOutput()` | Stream from sandbox tmux to Poco |
| `releaseTerminal()` | Sandbox cleanup |
| `waitForTerminalExit()` | Sandbox |
| `killTerminal()` | Sandbox |

**Interface calls on Poco (ACP SDK handles wire protocol):**

| Method | Trigger |
|--------|---------|
| `newSession()` | User creates a new chat in PocketBase |
| `loadSession()` / `resumeSession()` | User resumes existing chat |
| `closeSession()` | Chat closed |
| `prompt()` | User sends a message |
| `cancel()` | User cancels |
| `setSessionConfigOption()` | User changes model in UI |
| `authenticate()` | Provider auth (API keys, subscription) |

**Skip entirely:** NES (Next Edit Suggestions), document sync (`didOpen`, `didChange`, etc.), elicitation forms, provider list/set/disable, logout. These are editor-specific features.

**Command pump (PocketBase → Poco):**  
Unchanged in structure — PocketBase subscription detects new messages, maps to ACP calls instead of opencode SDK calls.

**Event pump (Poco → PocketBase):**  
Replaced by ACP callback implementations (`sessionUpdate`, `requestPermission`) instead of OpenCode SSE subscription.

**Execution proxying:**  
- `readTextFile` / `writeTextFile` — Interface reads/writes the shared `opencode_workspace` volume directly (Interface already has volume access; no remote sandbox call needed)
- `createTerminal` / terminal I/O callbacks — forward to the existing sandbox Rust proxy (`pocketcoder-proxy` on `:3001`). The proxy is unchanged — it still manages tmux sessions. ACP just replaces the proprietary wire above it.

### 2. `services/opencode` → rename to `services/poco`, parameterise agent CLI

Remove the hardcoded `opencode-ai@1.2.8` install. Make the agent CLI configurable via environment variable.

**Supported agents (Phase 1):**

| `POCO_AGENT` value | How it runs |
|---------------------|-------------|
| `opencode` (default) | `opencode acp` — native ACP support |
| `gemini` | `gemini` — production ACP reference (cloned at `.independent_repos/gemini-cli`) |
| `claude-code` | `@zed-industries/claude-code-acp` adapter wrapping Claude Code CLI |

Transport: ACP over WebSocket on a fixed port (e.g. `:4000`) so Interface can connect across Docker networks.

**Capability declaration:**  
On `initialize()`, Poco declares only the capabilities it supports. Interface uses capability negotiation — no hard failures if an agent doesn't support optional features.

### 3. Poco → Sandbox wiring — Option A (MCP passthrough)

Interface includes `mcpServers` in every `newSession()` call:

```typescript
await poco.newSession({
  workspaceFolders: [{ uri: workspaceUri }],
  mcpServers: [
    { type: "http", url: "http://sandbox:9888/mcp" }
  ]
})
```

Poco receives this and connects to poco-agents as MCP tools automatically. Sub-agents run in sandbox via poco-agents exactly as today.

**Why not Option B (sandbox agents as ACP `AgentSideConnection`):**  
Real-time streaming from sub-agents back to Poco pollutes Poco's context window with intermediate noise. Poco delegates tasks to sub-agents precisely to avoid processing that detail. Batch MCP (delegate → result) is the right coordination pattern for agent-to-agent. Human visibility into sub-agent activity is served by sub-agents writing directly to PocketBase, not by routing through Poco.

### 4. Docker Compose changes

- Rename `opencode` service → `poco`
- Remove `opencode-sdk` network (replaced by ACP network)
- Add `pocketcoder-acp` network connecting Interface ↔ Poco
- `POCO_AGENT` env var controls which CLI runs
- `POCO_ACP_PORT=4000` for WebSocket transport
- Interface env: `POCO_URL=ws://poco:4000`
- Remove `@opencode-ai/sdk` from interface dependencies
- Add `@agentclientprotocol/sdk` to interface dependencies

---

## What Is Not Changing

- `services/sandbox` — unchanged (pocketcoder-proxy, poco-agents MCP, tmux)
- `services/pocketbase` — unchanged
- PocketBase schema — unchanged
- Flutter client — unchanged
- MCP Gateway — unchanged
- The sandbox isolation model — ACP enforces it more cleanly, but the Rust proxy stays

---

## ACP Features Explicitly Out of Scope

| Feature | Reason |
|---------|--------|
| NES (Next Edit Suggestions) | Editor cursor/completion feature |
| Document sync (`didOpen`, `didChange`, etc.) | Editor feature |
| Elicitation forms | UI feature, no Flutter equivalent yet |
| Provider management (list/set/disable) | Agent CLI handles internally |
| `unstable_forkSession` | API surface not finalised |
| Option B sandbox ACP agents | Unnecessary complexity; MCP batch is better for agent coordination |

---

## Multi-Agent Routing (Phase 2)

Multiple Poco containers can run simultaneously (one per configured agent). Interface routes chats to the right Poco based on a `poco_agent` field on the PocketBase `chats` collection. A user could have one chat using Claude Code (Max subscription) and another using OpenCode (API), running concurrently.

This requires no ACP changes — Interface manages multiple `ClientSideConnection` instances, one per Poco container.

---

## Phasing

**Phase 1 — Interface rewrite + Poco parameterisation**
- Rewrite `services/interface` with ACP `ClientSideConnection`
- Rename `services/opencode` → `services/poco`, add `POCO_AGENT` config
- Wire OpenCode as default (`opencode acp`)
- Docker Compose updates

**Phase 2 — Additional Poco agents**
- Add Gemini CLI container config
- Add `claude-code-acp` adapter container config
- PocketBase `chats.poco_agent` field + Flutter model picker UI
- Interface multi-connection routing

**Phase 3 — Evaluate Option B**
- Revisit sandbox ACP agents if `unstable_forkSession` stabilises or a clear use case emerges

---

## Key Files

| File | Change |
|------|--------|
| `services/interface/src/index.ts` | Full rewrite — ACP replaces opencode SDK |
| `services/interface/package.json` | Swap `@opencode-ai/sdk` → `@agentclientprotocol/sdk` |
| `services/opencode/Dockerfile` | Rename dir, parameterise agent CLI install |
| `services/opencode/entrypoint.sh` | Rename dir, switch on `POCO_AGENT` env var |
| `docker-compose.yml` | Rename service, new network, new env vars |
