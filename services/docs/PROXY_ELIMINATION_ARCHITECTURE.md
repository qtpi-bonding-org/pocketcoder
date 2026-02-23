# Proxy Elimination Architecture

## Overview

Migrate from 4 containers (PocketBase + OpenCode + Proxy + Sandbox) to 3 containers (PocketBase + OpenCode + Sandbox). The Proxy container is eliminated. The Rust axum server and shell bridge move into the Sandbox. Tmux ownership moves to Sandbox.

## Current State (4 Containers)

```
PocketBase ←→ OpenCode ←→ Proxy ←→ Sandbox
  (memory)   (mem+ctrl)  (ctrl+exec)  (exec)
```

### Problems

1. Proxy owns tmux server. Subagent windows spawn in Proxy's PID namespace. `opencode` not found.
2. MCP relay is pure passthrough — adds latency and race conditions.
3. Legacy CAO relay is pure passthrough — no value.
4. 4 containers, 3 networks, SSH bridges, shared sockets — unnecessary complexity.

## End State (3 Containers)

```
PocketBase ←→ OpenCode ←→ Sandbox
  (memory)   (mem+ctrl)    (ctrl)
```

### Networks

```
pocketcoder-memory:   PocketBase ←→ OpenCode
pocketcoder-control:  OpenCode ←→ Sandbox
```

Sandbox cannot reach PocketBase. Linear isolation preserved.

## Container Responsibilities

### PocketBase (unchanged)

- User accounts, chats, messages, permissions
- Relay service (SSE subscriber to OpenCode)
- Network: `pocketcoder-memory`

### OpenCode (Poco — the brain)

- `opencode serve` on port 3000
- sshd on port 2222 (for Sandbox to create attach TUI pane)
- Built-in tools (read, edit, write, grep, glob) operate on local filesystem
- SHELL = compiled Rust binary (`pocketcoder-shell`) — POSTs bash to Sandbox
- Networks: `pocketcoder-memory` + `pocketcoder-control`

Volumes:
| Mount | Path | Mode | Purpose |
|-------|------|------|---------|
| `opencode_workspace` | `/workspace` | read-write | Poco's safe read/write space for source code |
| `sandbox_workspace` | `/sandbox` | read | Can read sandbox scratch space |
| `opencode_data` | `/root/.local/share/opencode` | read-write | Persistent OpenCode database |
| `shell_bridge` | `/proxy:ro` | read-only | Compiled Rust shell bridge binary |
| `.ssh_keys` | `/ssh_keys:ro` | read-only | SSH keys for Sandbox to connect |
| agents/proposals/skills | various | various | Agent config |

### Sandbox (the hands)

- Tmux server owner (creates and manages all sessions)
- Rust axum server on port 3001 (`/exec`, `/health`, `/sse`)
- CAO API server on port 9889 (terminal management, orchestration)
- CAO MCP server on port 9888 (handoff, assign, send_message, check_inbox)
- SSH client (creates Poco attach TUI window via SSH into OpenCode:2222)
- Pane health watchdog
- Subagent windows run natively (opencode installed here)
- Network: `pocketcoder-control`

Volumes:
| Mount | Path | Mode | Purpose |
|-------|------|------|---------|
| `opencode_workspace` | `/workspace` | read-only (future) | Read source code, cannot corrupt |
| `sandbox_workspace` | `/sandbox_workspace` | read-write-execute | Scratch space for execution |
| `tmux_socket` | `/tmp/tmux` | read-write | Tmux server socket (owned by Sandbox) |
| `shell_bridge` | `/app/shell_bridge:ro` | read-only | Rust binary shared to OpenCode |
| `.ssh_keys` | `/ssh_keys:ro` | read-only | SSH private key to connect to OpenCode |
| CAO src | `/app/cao/src` | bind mount | Live-edit CAO source |
| agent-store | agent-store path | bind mount | Subagent profiles |

## Security Model

| Tool | Runs Where | Filesystem Access |
|------|-----------|-------------------|
| read, edit, write, grep, glob | OpenCode | `opencode_workspace` (read-write) |
| bash (via shell bridge) | Sandbox | `opencode_workspace` (read-only future), `sandbox_workspace` (read-write-execute) |
| Subagent bash | Sandbox | Same as above |

- Poco's file operations happen in OpenCode where workspace is read-write. Safe from Sandbox explosions.
- Poco's bash commands execute in Sandbox. Cannot corrupt workspace (read-only) or OpenCode state (different container).
- Subagents run entirely in Sandbox. Same isolation.
- Rust shell bridge binary is compiled, mounted read-only. AI cannot modify it at runtime.

## Data Flow

### Poco bash command

```
Poco (serve) → bash tool → permission gate
  → SHELL=/proxy/pocketcoder-shell (compiled Rust)
  → HTTP POST sandbox:3001/exec
  → Rust axum server runs command in tmux pane (Sandbox namespace)
  → Polls capture-pane for sentinel
  → Returns stdout to Poco
```

### Poco file operations

```
Poco (serve) → read/edit/write tool
  → OpenCode built-in
  → Direct filesystem on /workspace (read-write)
  → No Sandbox involvement
```

### Subagent delegation (handoff)

```
Poco → handoff MCP tool → sandbox:9888
  → CAO creates tmux window (Sandbox namespace)
  → opencode run --agent developer (finds binary natively)
  → Completes, returns via MCP
```

### Subagent → Poco notification (async)

```
Subagent → send_message(poco_terminal_id, ...)
  → CAO inbox queues
  → Watchdog detects Poco pane IDLE
  → tmux send-keys to Poco's attach TUI pane
  → attach TUI → serve HTTP → Poco processes
```

### MCP tool discovery

```
OpenCode → GET sandbox:9888/sse (direct)
  → FastMCP SSE stream
  → POST sandbox:9888/messages/
  → Tools: handoff, assign, send_message, check_inbox
```

## Architecture Diagram

```
┌──────────────────────────────────────┐
│  OpenCode Container                  │
│  Networks: memory + control          │
│                                      │
│  opencode serve :3000                │
│  sshd :2222 (ForceCommand: attach)   │
│  SHELL=/proxy/pocketcoder-shell      │
│    → POSTs to sandbox:3001/exec      │
│                                      │
│  /workspace (rw) ← opencode_workspace│
│  /proxy (ro) ← shell_bridge volume   │
└──────────────┬───────────────────────┘
               │ control network
┌──────────────▼───────────────────────┐
│  Sandbox Container                   │
│  Network: control                    │
│                                      │
│  tmux server (OWNER)                 │
│    pocketcoder_session:              │
│      "poco" = SSH → OpenCode attach  │
│      "dev-xxxx" = subagent (native)  │
│                                      │
│  Rust axum :3001                     │
│    /exec, /health, /sse              │
│                                      │
│  CAO API :9889                       │
│  CAO MCP :9888                       │
│                                      │
│  SSH client + watchdog               │
│    → OpenCode:2222 for Poco pane     │
│                                      │
│  /workspace (ro future)              │
│    ← opencode_workspace             │
│  /sandbox_workspace (rwx)            │
│    ← sandbox_workspace              │
└──────────────────────────────────────┘
```

## Changes Required

### Phase 1: Build Rust binary in Sandbox image

**`docker/sandbox.Dockerfile`**
- Add Rust build stage (multi-stage, same as current proxy.Dockerfile builder)
- Compile `pocketcoder-proxy` binary
- Copy binary to `/app/pocketcoder` and `/app/shell_bridge/pocketcoder`
- Create `pocketcoder-shell` wrapper script in `/app/shell_bridge/`
- Install `openssh-client` (for SSH into OpenCode)

**`proxy/src/shell.rs`**
- Change default `PROXY_URL` from `http://proxy:3001` to `http://localhost:3001` (now same container)

**`proxy/src/main.rs`**
- Remove MCP relay handler (`mcp_sse_relay_handler`) — no longer needed
- Remove legacy proxy handler (`legacy_proxy_handler`) — no longer needed
- Remove `/mcp/*path` and `/messages/*` routes
- Keep: `/exec`, `/health`, `/sse` routes
- Keep: exec handler, SSE handler, driver

### Phase 2: Move tmux + SSH bridge to Sandbox

**`sandbox/entrypoint.sh`**
- Create tmux session (move from proxy entrypoint):
  ```
  tmux -S /tmp/tmux/pocketcoder new-session -d -s pocketcoder_session -n main
  chmod 777 /tmp/tmux/pocketcoder
  ```
- Start Rust axum server on port 3001 (background)
- Wait for OpenCode sshd, create Poco SSH window
- Add pane health watchdog loop
- Remove "wait for tmux socket" logic

**`docker/proxy_entrypoint.sh`**
- Delete entirely

### Phase 3: Update OpenCode

**`docker/opencode_entrypoint.sh`**
- Change proxy health check: `http://sandbox:3001/health` instead of `http://proxy:3001/health`
- Change MCP wait: `http://sandbox:9888/sse` instead of `http://proxy:3001/mcp/sse`
- Keep shell hardening (`/bin/sh → /proxy/pocketcoder-shell`)
- Keep wait for shell bridge binary

**`opencode.json`**
- MCP URL: `http://sandbox:9888/sse` (direct, no relay)

**`docker-compose.yml` — opencode service**
- `PROXY_URL=http://sandbox:3001` (where shell bridge POSTs)
- `SHELL=/proxy/pocketcoder-shell` (unchanged — binary path in container)
- Replace `proxy_bin:/proxy:ro` with `shell_bridge:/proxy:ro`

### Phase 4: Update docker-compose.yml

**Delete proxy service entirely**

**Networks**
- Delete `pocketcoder-execution`
- Sandbox joins `pocketcoder-control`
- Keep `pocketcoder-memory` (PocketBase ↔ OpenCode)

**Volumes**
- Rename `workspace_data` → `opencode_workspace`
- Add `sandbox_workspace` (new)
- Rename `proxy_bin` → `shell_bridge`
- Keep `tmux_socket`
- Keep `pb_data`, `pocketcoder-logs`, `opencode_data`

**Sandbox service**
```yaml
sandbox:
  build:
    context: .
    dockerfile: docker/sandbox.Dockerfile
  container_name: pocketcoder-sandbox
  volumes:
    - opencode_workspace:/workspace:ro    # Read-only (future: enforce)
    - sandbox_workspace:/sandbox_workspace # Read-write-execute scratch
    - tmux_socket:/tmp/tmux               # Tmux server (owned)
    - shell_bridge:/app/shell_bridge      # Rust binary shared to OpenCode
    - ./.ssh_keys:/ssh_keys:ro
    - ./sandbox/cao/src:/app/cao/src
    - ./agents/subagents:/root/.aws/cli-agent-orchestrator/agent-store
    - ./agents/poco/proposals:/workspace/.opencode/proposals
  environment:
    - TMUX_TMPDIR=/tmp/tmux
    - TMUX_SOCKET=/tmp/tmux/pocketcoder
    - SSH_KEYS_FILE=/ssh_keys/authorized_keys
  networks:
    - pocketcoder-control
```

**OpenCode service**
```yaml
opencode:
  build:
    context: .
    dockerfile: docker/opencode.Dockerfile
  container_name: pocketcoder-opencode
  environment:
    - PORT=3000
    - GEMINI_API_KEY=${GEMINI_API_KEY}
    - GOOGLE_GENERATIVE_AI_API_KEY=${GEMINI_API_KEY}
    - PROXY_URL=http://sandbox:3001
    - SHELL=/proxy/pocketcoder-shell
  volumes:
    - opencode_workspace:/workspace        # Read-write
    - shell_bridge:/proxy:ro               # Compiled Rust binary
    - opencode_data:/root/.local/share/opencode
    - ./.ssh_keys:/ssh_keys:ro
    - ./agents/poco/proposals:/workspace/.opencode/proposals
    - ./agents/poco/skills:/workspace/.opencode/skills:ro
    - ./opencode.json:/root/.config/opencode/opencode.json:ro
  networks:
    - pocketcoder-memory
    - pocketcoder-control
```

### Phase 5: Cleanup

- Delete `docker/proxy.Dockerfile`
- Delete `docker/proxy_entrypoint.sh`
- Remove MCP relay code from `proxy/src/main.rs`
- Remove legacy proxy handler from `proxy/src/main.rs`
- Update test scripts that reference `pocketcoder-proxy`
- Update `deploy.sh` log references
- Update `scripts/verify_linear_architecture.sh`

## Files Changed

| File | Action |
|------|--------|
| `docker-compose.yml` | Major rewrite — remove proxy, update volumes/networks |
| `docker/sandbox.Dockerfile` | Add Rust build stage, openssh-client |
| `sandbox/entrypoint.sh` | Add tmux creation, axum startup, SSH bridge, watchdog |
| `proxy/src/main.rs` | Strip to exec/health/sse only (remove MCP relay, legacy proxy) |
| `proxy/src/shell.rs` | Change default PROXY_URL to localhost:3001 |
| `docker/opencode_entrypoint.sh` | Point health checks at sandbox instead of proxy |
| `opencode.json` | MCP URL → sandbox:9888/sse |
| `docker/proxy.Dockerfile` | Delete |
| `docker/proxy_entrypoint.sh` | Delete |
| `sandbox/cao/src/.../constants.py` | Remove PUBLIC_URL comment referencing proxy |
| Test scripts | Update container references |
| `deploy.sh` | Remove proxy log reference |

## Migration Safety

Each phase is independently testable. Rollback = re-add proxy service to docker-compose and revert env vars.

## Open Questions

1. Should `opencode_workspace` be read-only for Sandbox now, or defer to a later phase?
   - Recommendation: read-write for now (matches current behavior), add `:ro` in a follow-up once we verify nothing in Sandbox writes to `/workspace`.

2. Should the Rust binary name change from `pocketcoder-proxy` to `pocketcoder-sentinel` or similar?
   - Recommendation: rename to `pocketcoder` (it's already called that in the binary). Update Cargo.toml package name.

3. Where does the Rust binary get compiled?
   - Recommendation: multi-stage build in `sandbox.Dockerfile`. First stage compiles Rust, second stage is the Python sandbox. Binary copied to both `/app/pocketcoder` (for axum server) and `/app/shell_bridge/pocketcoder` (shared to OpenCode via volume).
