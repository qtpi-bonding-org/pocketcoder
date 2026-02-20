# PocketCoder System Architecture

## What This Document Is

A ground-truth reference for how PocketCoder actually works right now. Every claim here is traced to a specific file in the codebase. If the code changes and this doc doesn't match, the code wins.

## The Five Containers

PocketCoder runs five Docker containers. This multi-container architecture ensures maximum isolation and security by separating the reasoning engine (OpenCode), the execution environment (Sandbox), the persistent state (PocketBase), and the external tool infrastructure (MCP Gateway).

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│   PocketBase     │       │    OpenCode      │       │    Sandbox       │
│   port 8090      │◄─────►│    port 3000     │◄─────►│    port 3001     │
│   (Relay)        │memory │    (Poco)        │control│    (CAO/Tmux)    │
└────────┬────────┘network └─────────────────┘network └────────┬────────┘
         │                                                     │
         │ mcp network                                         │ mcp network
         ▼                                                     ▼
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│ Docker Socket   │◄─────►│  MCP Gateway    │◄─────►│  (External)     │
│ Proxy (Secure)  │       │  port 8811      │       │  MCP Servers    │
└─────────────────┘       └─────────────────┘       └─────────────────┘
```

**Networks** (defined in `docker-compose.yml`):
- `pocketcoder-memory`: PocketBase ↔ OpenCode only (Sensitive state transition)
- `pocketcoder-control`: OpenCode ↔ Sandbox only (Execution control)
- `pocketcoder-mcp`: PocketBase ↔ Sandbox ↔ MCP Gateway ↔ Docker Proxy (Tool orchestration)

**The Linear Isolation Rule**:
Sandbox cannot reach OpenCode's API, and it cannot reach PocketBase directly. It can only communicate with the MCP Gateway for tools and receives command requests from the Proxy execution bridge. This ensures that the execution environment is truly "blind" to the reasoning engine's internals.

---

## Container 1: PocketBase

**Image**: Built from `docker/backend.Dockerfile` (Go binary compiled from `backend/`)
**Port**: 8090
**Network**: `pocketcoder-memory`

PocketBase is the database and the user-facing API. It stores chats, messages, permissions, subagents, SSH keys, agents, proposals, and SOPs. The Go binary embeds PocketBase and compiles in a custom Relay service.

### The Relay

The Relay is a Go module at `backend/pkg/relay/`. It's the nervous system — it bridges PocketBase and OpenCode. It starts when PocketBase boots (`relay.go` → `Start()`).

**What it does on startup** (`relay.go:Start()`):
1. Launches SSE listener in background goroutine (`listenForEvents()`)
2. Registers hooks: messages, agents, SSH keys, permissions, SOPs
3. Recovers any missed messages (`recoverMissedMessages()`)
4. Starts health monitor watchdog (20s ticker, 45s timeout)

**Hook registrations** (`relay.go:registerMessageHooks()`, etc.):

| Hook | Collection | Trigger | What Happens |
|------|-----------|---------|--------------|
| `OnRecordAfterCreateSuccess` | `messages` | User message created | `processUserMessage()` — sends to OpenCode |
| `OnRecordAfterCreateSuccess` | `ai_agents` | Agent created | `deployAgent()` — writes config to filesystem |
| `OnRecordAfterUpdateSuccess` | `ai_agents` | Agent updated | `deployAgent()` — rewrites config |
| `OnRecordAfterCreateSuccess` | `ssh_keys` | SSH key added | `syncSSHKeys()` — writes authorized_keys |
| `OnRecordAfterUpdateSuccess` | `ssh_keys` | SSH key changed | `syncSSHKeys()` — rewrites authorized_keys |
| `OnRecordAfterDeleteSuccess` | `ssh_keys` | SSH key removed | `syncSSHKeys()` — rewrites authorized_keys |
| `OnRecordAfterUpdateSuccess` | `permissions` | Permission status changed | `replyToOpenCode()` — sends approve/deny |
| `OnRecordAfterCreateSuccess` | `proposals` | Proposal created | `deployProposal()` — writes to filesystem |
| `OnRecordAfterUpdateSuccess` | `proposals` | Proposal updated | `deployProposal()` — rewrites |
| `OnRecordAfterCreateSuccess` | `sops` | SOP created | `deploySealedSop()` — writes skill file |
| `OnRecordAfterUpdateSuccess` | `sops` | SOP updated | `deploySealedSop()` — rewrites |

### Volumes

| Mount | Path | Mode | Purpose |
|-------|------|------|---------|
| `pb_data` | `/app/pb_data` | rw | PocketBase database |
| `pocketcoder-logs` | `/app/pb_public/logs` | rw | Log files |
| `opencode_workspace` | `/workspace` | rw | Shared workspace (for agent/SOP deployment) |
| `.ssh_keys` | `/ssh_keys` | rw | SSH authorized_keys file |

---

## Container 2: OpenCode (Poco)

**Image**: Built from `docker/opencode.Dockerfile` (Alpine + Bun + opencode-ai)
**Ports**: 3000 (API), 2222 (sshd)
**Networks**: `pocketcoder-memory` + `pocketcoder-control`
**Command**: `opencode serve --port 3000 --hostname 0.0.0.0 --log-level DEBUG`

OpenCode is the AI reasoning engine. It runs `opencode serve` which exposes an HTTP API and SSE event stream. It's called "Poco" (Private Operations Coding Officer).

### Entrypoint Flow (`docker/opencode_entrypoint.sh`)

1. **SSH setup**: Copies public key from `/ssh_keys/id_rsa.pub` to `/home/poco/.ssh/authorized_keys`, starts sshd on port 2222
2. **Shell bridge wait**: Polls for `/shell_bridge/pocketcoder-shell` (up to 120s). This binary is populated by Sandbox via the `shell_bridge` shared volume.
3. **Shell hardening**: Replaces `/bin/sh` symlink → `/shell_bridge/pocketcoder-shell`. After this, every `sh -c "cmd"` invocation by OpenCode routes through the Rust shell bridge to Sandbox.
4. **Background health checks** (non-blocking):
   - Polls `http://sandbox:3001/health` (Rust axum)
   - Polls `http://sandbox:9888/sse` (CAO MCP)
5. **Launch**: `exec opencode serve --port 3000 ...`

### sshd Configuration (`docker/opencode.Dockerfile`)

The `poco` user has a `ForceCommand`:
```
ForceCommand /usr/local/bin/opencode attach http://localhost:3000 --continue
```

When Sandbox SSHes in as `poco@opencode:2222`, it gets an `opencode attach` TUI session — not a shell. This is how the Poco tmux window in Sandbox connects to the running OpenCode serve instance.

### Shell Hardening

After the entrypoint runs, `/bin/sh` points to `/shell_bridge/pocketcoder-shell`. This is a compiled Rust binary (built in Sandbox's Dockerfile, shared via volume). When OpenCode's bash tool calls `sh -c "some command"`, it actually runs:

```
/shell_bridge/pocketcoder-shell -c "some command"
```

Which the Rust binary (`proxy/src/shell.rs`) handles by:
1. Parsing the `-c` argument
2. Reading `OPENCODE_SESSION_ID` and `PROXY_URL` from env
3. POSTing `{"cmd": "some command", "cwd": "/workspace", "session_id": "..."}` to `http://sandbox:3001/exec`
4. Printing the response stdout and exiting with the response exit code

### MCP Configuration (`opencode.json`)

```json
"mcp": {
  "cao": {
    "type": "remote",
    "url": "http://sandbox:9888/sse",
    "enabled": true,
    "timeout": 120000
  }
}
```

OpenCode connects directly to CAO's MCP server in Sandbox. No relay or proxy in between. Tools available: `cao_handoff`, `cao_assign`, `cao_send_message`, `cao_check_inbox`.

### Volumes

| Mount | Path | Mode | Purpose |
|-------|------|------|---------|
| `shell_bridge` | `/shell_bridge` | ro | Compiled Rust binary + wrapper script |
| `opencode_workspace` | `/workspace` | rw | Source code workspace |
| `opencode_data` | `/root/.local/share/opencode` | rw | OpenCode's internal database |
| `.ssh_keys` | `/ssh_keys` | ro | SSH keys for Sandbox to connect |
| `opencode.json` | `/root/.config/opencode/opencode.json` | ro | OpenCode configuration |
| proposals | `/workspace/.opencode/proposals` | rw | Agent proposals |
| skills | `/workspace/.opencode/skills` | ro | Agent skills/SOPs |

---

## Container 3: Sandbox

**Image**: Built from `docker/sandbox.Dockerfile` (multi-stage: Rust builder + Python runtime)
**Ports**: 3001 (Rust axum), 9889 (CAO API), 9888 (CAO MCP), 2222 (sshd for worker)
**Network**: `pocketcoder-control`

Sandbox is the execution environment. It owns tmux, runs the Rust exec server, runs CAO, and is where all bash commands actually execute.

### Build Stages (`docker/sandbox.Dockerfile`)

**Stage 1 — Rust builder**:
- Base: `rust:1.83-alpine`
- Compiles `proxy/` source into `pocketcoder-proxy` binary
- Uses dependency caching (dummy main.rs trick)

**Stage 2 — Runtime**:
- Base: `python:3.11-slim-bookworm`
- Installs: tmux, openssh-server, openssh-client, sqlite3, terraform, bun, opencode-ai, uv
- Copies Rust binary to `/app/pocketcoder` and `/app/shell_bridge/pocketcoder`
- Creates wrapper script `/app/shell_bridge/pocketcoder-shell`
- Installs CAO from `/app/cao` (vendored Python package)

### Entrypoint Flow (`sandbox/entrypoint.sh`)

1. **Cleanup**: Wipes stale tmux sockets, CAO lock files
2. **Shell bridge population**: Copies `/app/pocketcoder` → `/app/shell_bridge/pocketcoder`, creates wrapper script. This populates the `shell_bridge` shared volume so OpenCode can access the binary.
3. **Tmux creation**: `tmux -S /tmp/tmux/pocketcoder new-session -d -s pocketcoder_session -n main`
4. **Rust axum server**: `/app/pocketcoder server --port 3001 &` (background)
5. **sshd**: Starts on port 2222 (for `worker` user access)
6. **SSH key sync**: Polls for keys from shared volume
7. **CAO API server**: `uv run cao-server` on port 9889 (background)
8. **CAO MCP server**: `uv run cao-mcp-server` on port 9888 in SSE mode (background)
9. **Poco window**: Waits for OpenCode sshd (port 2222), then creates tmux window:
   ```
   tmux new-window -t pocketcoder_session -n poco \
       "ssh -t -o StrictHostKeyChecking=no -i /ssh_keys/id_rsa poco@opencode -p 2222"
   ```
   This SSH session triggers the ForceCommand on OpenCode, giving an `opencode attach` TUI.
10. **Pane watchdog**: Every 10s, checks if the `poco` window exists. Recreates it if missing.
11. **CAO registration**: Registers the Poco terminal with CAO:
    ```
    POST http://localhost:9889/sessions?provider=opencode-attach&agent_profile=poco&session_name=pocketcoder_session&delegating_agent_id=poco
    ```
12. **Tail**: `tail -f /dev/null` to keep container alive.

### Rust Axum Server (`proxy/src/main.rs`)

Three routes:

| Route | Method | Handler | Purpose |
|-------|--------|---------|---------|
| `/health` | GET | `health_handler` | Returns `"ok"` |
| `/sse` | GET | `sse_handler` | SSE stream (session-based) |
| `/exec` | POST | `exec_handler` | Execute command in tmux |

The `/exec` endpoint accepts:
```json
{
  "cmd": "echo hello",
  "cwd": "/workspace",
  "session_id": "opencode-session-id",
  "usage_id": "optional"
}
```

And returns:
```json
{"stdout": "hello", "exit_code": 0}
```

Or on error:
```json
{"error": "Command execution timed out (Sandbox).", "exit_code": 1}
```

### Exec Driver (`proxy/src/driver.rs`)

The driver is the core execution logic. When `/exec` is called:

1. **Session resolution** (`resolve_session_and_window()`):
   - Queries CAO: `GET http://sandbox:9889/terminals/by-delegating-agent/{session_id}`
   - CAO returns `{"tmux_session": "pocketcoder_session", "tmux_window_id": 1, ...}`
   - Extracts session name and window ID

2. **Command injection**:
   - Clears tmux pane history (Ctrl-C, clear, clear-history)
   - Wraps command with sentinel: `{cmd}; echo "---POCKETCODER_EXIT:$?_ID:{uuid}---"`
   - Sends to tmux pane via `tmux send-keys`

3. **Output capture** (poll loop):
   - Every 200ms, runs `tmux capture-pane -p`
   - Looks for `POCKETCODER_EXIT` + matching sentinel UUID
   - Extracts exit code from `POCKETCODER_EXIT:{exit_code}_ID:{sentinel_id}`
   - Filters out sentinel lines and cd commands from output
   - Timeout: 300 seconds

### CAO (CLI Agent Orchestrator)

CAO is a Python application at `sandbox/cao/`. It runs two servers:

**API Server** (port 9889, `sandbox/cao/src/cli_agent_orchestrator/api/main.py`):
- `GET /health` — health check
- `POST /sessions` — create session
- `GET /sessions` — list sessions
- `GET /sessions/{name}` — get session
- `DELETE /sessions/{name}` — delete session
- `POST /sessions/{name}/terminals` — create terminal in session
- `GET /sessions/{name}/terminals` — list terminals
- `GET /terminals/{id}` — get terminal
- `GET /terminals/by-delegating-agent/{id}` — lookup by delegating agent (used by Rust driver)
- `POST /terminals/{id}/input` — send input
- `GET /terminals/{id}/output` — get output
- `POST /terminals/{id}/exit` — exit terminal
- `DELETE /terminals/{id}` — delete terminal
- `POST /inbox` — create inbox message
- `GET /inbox` — get inbox messages

**MCP Server** (port 9888, `sandbox/cao/src/cli_agent_orchestrator/mcp_server/server.py`):
- Transport: SSE (OpenCode connects to `http://sandbox:9888/sse`)
- Tools exposed:
  - `handoff` — create terminal, wait for completion, return HandoffResult (synchronous)
  - `assign` — create terminal, send message, return immediately (async)
  - `send_message` — send message to another agent's inbox
  - `check_inbox` — check current agent's inbox

### HandoffResult Model (`sandbox/cao/src/cli_agent_orchestrator/mcp_server/models.py`)

```python
class HandoffResult(BaseModel):
    pocketcoder_sys_event: str = Field(
        default="handoff_complete",
        alias="_pocketcoder_sys_event",
    )
    success: bool
    message: str
    output: Optional[str]
    terminal_id: Optional[str]
    subagent_id: Optional[str]
    tmux_window_id: Optional[int]
    agent_profile: Optional[str]
```

Serializes to flat JSON with `_pocketcoder_sys_event` at the top level (not nested under a `payload` wrapper). This is the discriminator that Relay uses to detect subagent registrations.

### Volumes

| Mount | Path | Mode | Purpose |
|-------|------|------|---------|
| `opencode_workspace` | `/workspace` | rw | Shared workspace |
| `shell_bridge` | `/app/shell_bridge` | rw | Rust binary shared to OpenCode |
| `.ssh_keys` | `/ssh_keys` | ro | SSH keys |
| CAO src | `/app/cao/src` | bind | Live-edit CAO source |
| agent-store | `/root/.aws/cli-agent-orchestrator/agent-store` | bind | Subagent profiles |
| proposals | `/workspace/.opencode/proposals` | bind | Agent proposals |
| skills | `/workspace/.opencode/skills` | bind | Agent skills/SOPs |

---

## Container 4: MCP Gateway

**Image**: Built from `docker/mcp-gateway.Dockerfile`
**Port**: 8811
**Network**: `pocketcoder-mcp`

The MCP Gateway is a specialized router for [Model Context Protocol](https://modelcontextprotocol.io) servers. It allows Sandbox to discover and invoke tools provided by external containers (like the Terraform or Git MCP servers).

- **Function**: Aggregates multiple tool servers into a single SSE endpoint.
- **Security**: Sandbox only talks to the Gateway, not the individual tool containers.

---

## Container 5: Docker Socket Proxy (Secure)

**Image**: `tecnativa/docker-socket-proxy`
**Network**: `pocketcoder-mcp`

This is the security gate for Docker interactions. Instead of mounting `/var/run/docker.sock` directly into the Sandbox (which would grant root access to the host), both the Gateway and PocketBase communicate through this proxy.

- **Hardened Rules**:
  - `CONTAINERS=1`: Allows listing and restarting specific containers.
  - `POST=1`: Necessary for restart operations.
  - `IMAGES=0`, `NETWORKS=0`, `EXEC=0`: Disables destructive or sensitive operations.
- **Isolation**: Ensures that even if the Sandbox is compromised, the attacker cannot gain control over host networks or other containers.

---

## Data Flows

### Flow 1: User Sends a Message

This is the primary flow. A user types a message in the PocketBase UI, and it flows through all three containers.

```
User → PocketBase API → Relay hook → OpenCode → Shell Bridge → Sandbox → tmux
                                         ↑                                  │
                                         │          (synchronous response)  │
                                         ←──────────────────────────────────┘
                                         │
                                    SSE event
                                         │
                                         ↓
                                   Relay listener → PocketBase (persist)
```

Step by step:

1. **User creates message**: `POST /api/collections/messages/records` with `role: "user"`, `user_message_status: "pending"`

2. **Relay hook fires** (`relay.go:registerMessageHooks()`): `OnRecordAfterCreateSuccess("messages")` triggers `processUserMessage()`

3. **processUserMessage()** (`messages.go`):
   - Sets `user_message_status: "sending"`
   - Sets chat `turn: "assistant"`
   - Calls `ensureSession(chatID)`

4. **ensureSession()** (`messages.go`):
   - Checks if chat already has `ai_engine_session_id`
   - If yes: verifies session is alive via `GET {OPENCODE_URL}/session/{id}` (200 = alive, 404 = dead)
   - If no (or dead): creates new session via `POST {OPENCODE_URL}/session` with `{"directory": "/workspace", "agent": "build"}`
   - Stores `ai_engine_session_id` in chat record

5. **Message delivery**: `POST {OPENCODE_URL}/session/{id}/prompt_async` with `{"parts": [...]}`
   - Sets `user_message_status: "delivered"` on success

6. **OpenCode processes**: The AI reasons about the message. When it needs to run a command, it invokes the bash tool.

7. **Shell bridge** (`proxy/src/shell.rs`): OpenCode's bash tool calls `sh -c "command"` which is now `/shell_bridge/pocketcoder-shell -c "command"`. The Rust binary:
   - Reads `OPENCODE_SESSION_ID` from env
   - POSTs to `http://sandbox:3001/exec` with `{"cmd": "command", "cwd": "/workspace", "session_id": "..."}`

8. **Rust axum handler** (`proxy/src/main.rs:exec_handler()`): Passes to driver.

9. **Driver** (`proxy/src/driver.rs:exec()`):
   - Resolves session via CAO: `GET http://sandbox:9889/terminals/by-delegating-agent/{session_id}`
   - Injects command into tmux pane with sentinel
   - Polls `tmux capture-pane` every 200ms until sentinel appears
   - Returns `{"stdout": "...", "exit_code": N}`

10. **Shell bridge returns**: Prints stdout, exits with exit code. OpenCode sees the output.

11. **SSE sync**: OpenCode emits `message.updated` events on its SSE stream.

12. **Relay listener** (`permissions.go:listenForEvents()`): Connected to `{OPENCODE_URL}/event`. Receives the event, calls `syncAssistantMessage()`.

13. **syncAssistantMessage()** (`messages.go`): Upserts assistant message record in PocketBase with `ai_engine_message_id`, `parts`, `engine_message_status`. Updates chat `last_active` and `preview`.

14. **Session idle**: When OpenCode finishes, it emits `session.idle`. Relay's `handleSessionIdle()` flips chat `turn` back to `"user"`.

### Flow 2: Permission Gating

When OpenCode wants to run a bash command or edit a file, it asks for permission.

1. **OpenCode emits** `permission.asked` SSE event with `id`, `permission` type, `patterns`, `metadata`, `sessionID`

2. **Relay receives** via `listenForEvents()` → `handlePermissionAsked()` (`permissions.go`)

3. **handlePermissionAsked()**:
   - Resolves chat ID from session ID
   - Evaluates against whitelists using `permission.Evaluate()`
   - Creates permission record in PocketBase with `status: "authorized"` (if whitelisted) or `status: "draft"` (if gated)
   - If whitelisted: immediately calls `replyToOpenCode(permID, "once")`
   - If gated: waits for user action

4. **User approves** (updates permission record `status: "authorized"`):
   - `registerPermissionHooks()` fires `OnRecordAfterUpdateSuccess("permissions")`
   - Calls `replyToOpenCode(permID, "once")`

5. **replyToOpenCode()** (`permissions.go`): `POST {OPENCODE_URL}/permission/{id}/reply` with `{"reply": "once"}` (or `"reject"`)

### Flow 3: Subagent Delegation (Handoff)

When Poco needs a specialist, it uses the CAO MCP handoff tool.

1. **Poco calls** `cao_handoff` MCP tool via `http://sandbox:9888/sse`

2. **CAO MCP server** (`server.py:_handoff_impl()`):
   - Creates terminal via CAO API
   - Creates tmux window in `pocketcoder_session`
   - Initializes agent provider (opencode, kiro, etc.)
   - Waits for completion

3. **Subagent runs**: In its own tmux window inside Sandbox. Has access to opencode-ai binary natively.

4. **HandoffResult returned**: Flat JSON with `_pocketcoder_sys_event: "handoff_complete"`, `subagent_id`, `terminal_id`, `tmux_window_id`, `agent_profile`

5. **OpenCode emits** `message.updated` SSE event containing the tool result

6. **Relay receives** → `syncAssistantMessage()` → `checkForSubagentRegistration()` (`messages.go`):
   - Scans message parts for tool results
   - Handles both `type: "tool_result"` (legacy) and `type: "tool"` (OpenCode format with `state.output`)
   - Checks tool name: `handoff`, `assign`, `cao_handoff`, `cao_assign`
   - Parses JSON content, looks for `_pocketcoder_sys_event: "handoff_complete"` at top level
   - Extracts `subagent_id`, `terminal_id`, `tmux_window_id`, `agent_profile`

7. **registerSubagentInDB()** (`messages.go`):
   - Looks up chat's `ai_engine_session_id` to get `delegating_agent_id`
   - Creates record in `subagents` collection with `subagent_id`, `delegating_agent_id`, `tmux_window_id`, `chat`

### Flow 4: SSH Key Distribution

1. User adds/updates/deletes SSH key in PocketBase `ssh_keys` collection
2. Relay hook fires → `syncSSHKeys()` (`ssh.go`)
3. Fetches all active keys, writes to `/ssh_keys/authorized_keys` (shared volume)
4. Both OpenCode and Sandbox mount this volume and pick up the keys

### Flow 5: Agent and SOP Deployment

1. User creates/updates agent in `ai_agents` collection → Relay `deployAgent()` writes `.md` file to filesystem
2. User creates/updates proposal in `proposals` collection → Relay `deployProposal()` writes to `/workspace/.opencode/proposals/`
3. User creates/updates SOP in `sops` collection → Relay `deploySealedSop()` writes to `/workspace/.opencode/skills/{name}/SKILL.md`

---

## Session Identity Resolution

This is how the system maps an OpenCode session to the right tmux pane.

**The chain**: `OPENCODE_SESSION_ID` → shell bridge → `/exec` → driver → CAO lookup → tmux pane

1. OpenCode sets `OPENCODE_SESSION_ID` env var for each session
2. Shell bridge reads it and includes it in the `/exec` POST as `session_id`
3. Driver calls `resolve_session_and_window(session_id)`:
   - `GET http://sandbox:9889/terminals/by-delegating-agent/{session_id}`
   - CAO looks up terminal by `delegating_agent_id` field
   - Returns `tmux_session` and `tmux_window_id`
4. Driver targets pane: `{tmux_session}:{window_id}.0`

**For Poco**: The Poco terminal is registered at startup with `delegating_agent_id=poco`. When OpenCode's session ID resolves through CAO, it finds the Poco window.

**For subagents**: Each subagent gets its own terminal registered with CAO. The `delegating_agent_id` is the subagent's OpenCode session ID.

**resolveChatID()** (`utils.go`): The reverse lookup. Given a session ID, find the chat:
1. Check `chats` collection for `ai_engine_session_id = session_id`
2. If not found, check `subagents` collection for `subagent_id = session_id`, then follow `delegating_agent_id` → `chats.ai_engine_session_id`

---

## Shared Volumes

| Volume | OpenCode Mount | Sandbox Mount | PocketBase Mount | Purpose |
|--------|---------------|---------------|-----------------|---------|
| `opencode_workspace` | `/workspace` (rw) | `/workspace` (rw) | `/workspace` (rw) | Source code |
| `shell_bridge` | `/shell_bridge` (ro) | `/app/shell_bridge` (rw) | — | Rust binary |
| `.ssh_keys` | `/ssh_keys` (ro) | `/ssh_keys` (ro) | `/ssh_keys` (rw) | SSH keys |
| `opencode_data` | `/root/.local/share/opencode` (rw) | — | — | OpenCode DB |
| `pb_data` | — | — | `/app/pb_data` (rw) | PocketBase DB |

The `shell_bridge` volume is the key mechanism: Sandbox builds the Rust binary and writes it to the volume. OpenCode mounts it read-only and uses it as its shell. This is how commands cross the container boundary without SSH or socket sharing.

---

## Startup Order

1. **OpenCode** starts first (no dependencies). Begins serving on port 3000. Starts sshd on 2222. Waits for shell bridge binary in background.
2. **Sandbox** starts. Populates `shell_bridge` volume (unblocks OpenCode's shell). Creates tmux session. Starts Rust axum, CAO API, CAO MCP. Waits for OpenCode sshd, creates Poco window. Registers Poco with CAO.
3. **PocketBase** starts last. Waits for OpenCode to be reachable (`curl http://opencode:3000`). Starts PocketBase, which starts the Relay. Relay connects SSE listener to OpenCode.

The `docker-compose.yml` doesn't use `depends_on` — each container handles its own readiness polling.
