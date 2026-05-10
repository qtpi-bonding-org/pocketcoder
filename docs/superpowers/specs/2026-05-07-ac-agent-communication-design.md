# AC — Agent Communication Design

**Date:** 2026-05-07  
**Status:** Draft  
**Scope:** Standalone package that bridges ACP-compliant agent CLIs to the outside world via switchable input/output adapters. Consumed by PocketCoder; also usable as a naked CLI tool.

---

## Problem

Agent CLIs (Claude Code, OpenCode, Gemini) all speak ACP internally but there is no generic way to:
1. Call them as A2A sub-agents from an orchestrator
2. Reuse that wiring in PocketCoder without baking PocketBase into the bridge

---

## Solution

AC (Agent Communication) is a TypeScript/Bun library with:
- An **ACP core** that always speaks ACP to the CLI subprocess
- **Switchable input/output adapters** so the same core serves multiple contexts

```
[input adapter]  →  ACP core  →  [output adapter]
```

---

## Adapters

| Context | Input adapter | Output adapter |
|---|---|---|
| PocketCoder | PocketBase subscription | PocketBase writes |
| A2A sub-agent | A2A task request | A2A event bus |
| Naked CLI | stdin / CLI args | stdout |

---

## ACP Core

The core always speaks ACP to the CLI subprocess. The CLI runs via `opencode acp`, `claude-code-acp`, or `gemini` (ACP mode). The core:

1. Spawns the CLI process (`poco-process`)
2. Acts as the ACP `ClientSideConnection` (`acp-client`)
3. Handles ACP callbacks:
   - `readTextFile` / `writeTextFile` → local FS (naked) or sandbox proxy (PocketCoder)
   - `createTerminal` / terminal I/O → local pty (naked) or sandbox proxy (PocketCoder)
   - `requestPermission` → permission handler (pluggable)
   - `sessionUpdate` → routes to output adapter
4. Sends tasks via `command-pump` (input adapter → ACP `newSession` + `prompt`)
5. Routes events via `event-pump` (ACP callbacks → output adapter)

---

## Permission Handling

Permissions are an ACP concept, not A2A. The core intercepts `requestPermission()` and delegates to a pluggable `PermissionHandler`:

| Handler | Behaviour |
|---|---|
| `AutoApprove` | Always returns allow — for trusted autonomous sub-agents |
| `BubbleUp` | A2A mode: emits `input-required` task state, waits for orchestrator response. Stdin mode: prompts terminal user interactively. |

---

## Harnesses

| `HARNESS` value | ACP command |
|---|---|
| `opencode` | `opencode acp` |
| `claude-code` | via `@zed-industries/claude-code-acp` |
| `gemini` | `gemini` (native ACP) |

---

## A2A Server

The A2A server wraps AC core in an `AgentExecutor` (from `@a2a-js/sdk`). It:
1. Receives an A2A task
2. Creates AC core with `a2a` input + output adapters
3. Runs the task
4. Emits `TaskStatusUpdateEvent` (progress) and `TaskArtifactUpdateEvent` (result)
5. Exposes agent card at `/.well-known/agent-card.json`

---

## `a2a-delegate` CLI

A thin binary that wraps AC in A2A mode. Called by orchestrator CLIs via bash:

```bash
a2a-delegate --agent opencode --task "write the auth module"
# streams progress to stderr, result to stdout, exits 0 on success
```

Configuration via `~/.config/ac/config.yaml`:
```yaml
agents:
  opencode:
    harness: opencode
    url: http://localhost:4001   # if running as A2A server
  claude-code:
    harness: claude-code
    url: http://localhost:4002
```

---

## Repo Structure

```
ac/
  packages/
    core/
      src/
        types.ts              shared interfaces: OutputAdapter, PermissionHandler, Task
        poco-process.ts       spawn CLI subprocess in ACP mode
        sandbox-proxy.ts      file read/write (local FS), terminal (node-pty)
        acp-client.ts         ACP ClientSideConnection — routes callbacks
        event-pump.ts         ACP sessionUpdate → OutputAdapter
        command-pump.ts       Task → ACP newSession + prompt
      package.json

    adapters/
      src/
        output/
          stdout.ts           stream events to stdout as ndjson
          a2a.ts              emit A2A TaskStatusUpdateEvent / TaskArtifactUpdateEvent
          pocketbase.ts       write to PB messages / permissions / acp_terminals (Phase 3)
        input/
          stdin.ts            read task from stdin or CLI args
          a2a.ts              A2A RequestContext → Task
          pocketbase.ts       PB messages subscription → Task (Phase 3)
        permissions/
          auto-approve.ts     always allow
          bubble-up.ts        input-required (A2A) or interactive terminal prompt (stdin)
      package.json

    a2a-server/
      src/
        agent-card.ts         AgentCard definition per harness
        executor.ts           AgentExecutor wrapping AC core
        server.ts             Express + A2A SDK server
      package.json

    cli/
      src/
        a2a-delegate.ts       CLI entry point
      package.json

  package.json                Bun workspace root
  config.yaml.example
```

---

## PocketCoder Integration

**Phase 3 (PocketBase adapters) is cancelled.** `services/interface` keeps its own PocketBase-specific implementations and does not import from `@ac/core`. The reasons:

- Interface's `sandbox-proxy.ts` proxies over HTTP to the Rust proxy at `http://sandbox:3001` — structurally different from aca-bridge's local FS/pty implementation.
- Interface's pumps are tightly coupled to PocketBase schema (`poco_configs`, `acp_terminals`, permission polling) — writing PocketBase adapters for aca-bridge would just replicate what Interface already does, behind an extra abstraction layer.
- No user-facing benefit. Interface works. Adding the dependency couples a service to a library to share ~50 lines of generic plumbing.

**aca-bridge's only role in PocketCoder is the sandbox A2A server.** It runs inside the sandbox container alongside `poco-agents`, replacing `spawn_agent` / `check_agent` / `list_agents` MCP tools. Poco calls `http://sandbox:4001/a2a` directly to delegate full tasks to sub-agent CLIs.
