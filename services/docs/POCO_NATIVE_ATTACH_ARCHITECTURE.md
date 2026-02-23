# Poco Native Attach Architecture

## Overview

This document describes the target architecture for making Poco (the head agent running OpenCode in `serve` mode) a native participant in the CAO subagent ecosystem, enabling real-time bidirectional communication without the `prompt_async` nudge hack.

## Problem Statement

Poco runs OpenCode in `serve` mode inside the OpenCode container (Zone B). Serve mode exposes an HTTP API but does not read stdin. This means:

- Subagents in the sandbox can't notify Poco natively through CAO's inbox delivery system
- The only way to push messages to Poco is `prompt_async`, which injects fake "user" messages into the conversation
- Poco is invisible to CAO — it has no terminal ID, no tmux presence, no status detection
- The `_notify_brain()` nudge in the CAO MCP server is a bolted-on workaround that bypasses CAO's delivery infrastructure

## Solution: SSH-Bridged Attach TUI

Run `opencode attach` inside the OpenCode container, connected to the local `serve` instance, with its terminal I/O bridged into a tmux pane via SSH. This gives Poco a real tmux presence that CAO can interact with natively.

The `attach` TUI is used **exclusively for inbound message delivery** (subagent → Poco). Poco's outbound execution (shell commands, file operations) continues to use the existing proxy shell bridge (`pocketcoder-shell` → HTTP POST → Proxy → tmux `send-keys` in sandbox).

## Architecture Diagram

```
┌──────────────────────────────────────┐
│  OpenCode Container (Zone B)         │
│  Networks: memory + control          │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ opencode serve --port 3000    │  │
│  │ - HTTP API (Relay, MCP)       │  │
│  │ - SSE event stream            │  │
│  │ - SHELL=/proxy/pocketcoder-sh │  │
│  │ - Private volumes             │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ sshd on :2222                 │  │
│  │ - Key auth only               │  │
│  │ - ForceCommand restricts to   │  │
│  │   opencode attach             │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ opencode attach               │  │
│  │   http://localhost:3000       │  │
│  │   --continue                  │  │
│  │                               │  │
│  │ - Launched via SSH session    │  │
│  │ - Full TUI with idle/busy    │  │
│  │ - Reads input from SSH PTY   │  │
│  │ - Sends to serve via HTTP    │  │
│  │ - Displays responses         │  │
│  │ - Uses local filesystem for  │  │
│  │   state (kv.json, model.json)│  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────┬───────────────────────┘
               │ SSH tunnel (PTY I/O only)
               │ Port 2222, control network
               │
┌──────────────▼───────────────────────┐
│  Proxy Container                     │
│  Networks: control + execution       │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ tmux server (OWNER)           │  │
│  │ Socket: /tmp/tmux/pocketcoder │  │
│  │                               │  │
│  │ Session: pocketcoder_session  │  │
│  │ Window "poco":                │  │
│  │   ssh -t poco@opencode:2222   │  │
│  │                               │  │
│  │ (Subagent windows created by  │  │
│  │  CAO via shared socket)       │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Proxy HTTP Server (:3001)     │  │
│  │ - /exec (shell bridge)        │  │
│  │ - /mcp/* (MCP relay to CAO)   │  │
│  │ - /notify (legacy, optional)  │  │
│  │ - /health                     │  │
│  └────────────────────────────────┘  │
│                                      │
│  Zero OpenCode dependencies.         │
│  Pure Rust + tmux + ssh client.      │
│                                      │
└──────────────┬───────────────────────┘
               │ tmux socket (shared volume)
               │
┌──────────────▼───────────────────────┐
│  Sandbox Container (Zone D)          │
│  Network: execution only             │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ tmux client (shared socket)   │  │
│  │                               │  │
│  │ pocketcoder_session:          │  │
│  │ ┌──────────┐ ┌──────────┐   │  │
│  │ │ window 0 │ │ window 1 │   │  │
│  │ │ "poco"   │ │ subagent │   │  │
│  │ │ (attach) │ │ (native) │   │  │
│  │ └──────────┘ └──────────┘   │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ CAO API Server (:9889)        │  │
│  │ CAO MCP Server (:9888)        │  │
│  │                               │  │
│  │ Poco = registered terminal    │  │
│  │ Inbox delivery: tmux send-keys│  │
│  │ Status detection: TUI regex   │  │
│  │ No special provider needed*   │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘

* A new "attach" provider with TUI-specific regex patterns
  is needed for status detection, but the delivery mechanism
  is standard tmux send-keys — no special routing.
```

## Data Flow

### Outbound: Poco → Sandbox (unchanged)

```
Poco (serve) → bash tool call → OpenCode permission gate
  → SHELL=/proxy/pocketcoder-shell
  → HTTP POST proxy:3001/exec
  → Proxy injects into sandbox tmux via send-keys
  → Proxy polls capture-pane for sentinel
  → Returns stdout to Poco
```

This path is completely unchanged. The proxy shell bridge continues to handle
all of Poco's outbound execution.

### Inbound: Subagent → Poco (NEW — replaces nudge)

```
Subagent finishes task
  → Calls send_message(poco_terminal_id, "results...")
  → CAO inbox queues message as PENDING
  → PollingObserver watchdog checks Poco's pane
  → Detects IDLE state via attach TUI regex
  → Delivers via tmux send-keys to Poco's pane
  → attach TUI receives input
  → attach sends to serve instance via HTTP (localhost:3000)
  → Poco processes the message
  → Response appears in attach TUI pane
  → Watchdog detects IDLE again, delivers next queued message
```

### Relay/PocketBase Path (unchanged)

```
PocketBase Relay → SSE subscribe to opencode:3000/event
  → Captures thoughts, tool calls, permission requests
  → Logs to database, pushes to Flutter app

Flutter App → PocketBase → Relay → prompt_async to opencode:3000
  → User messages delivered via HTTP API
```

## Linear Architecture Preservation

```
PocketBase ←→ OpenCode ←→ Proxy ←→ Sandbox
 (memory)     (control)   (both)   (execution)
```

- Sandbox NEVER contacts OpenCode directly
- SSH originates from Proxy → OpenCode (control network)
- The tmux pane is a PTY pipe, not a network channel
- Sandbox interacts with the pane via tmux commands through the shared socket
- The shared socket only carries tmux protocol, not arbitrary network traffic

## Component Changes

### OpenCode Container

**New: sshd service**

Add a minimal SSH daemon for the Proxy to connect to.

- Install `openssh-server` (Alpine: ~2MB)
- Create a dedicated `poco` user with no shell access
- Key-based authentication only (no passwords)
- `ForceCommand` restricts SSH sessions to running `opencode attach`

sshd_config additions:
```
Port 2222
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers poco
Match User poco
    ForceCommand opencode attach http://localhost:3000 --continue
```

**New: SSH key generation**

On first boot, generate an SSH keypair. The public key is shared with the
Proxy via a volume mount. The private key stays in the Proxy container.

Alternatively, use a shared volume for the keypair generated by the Proxy
at startup.

**Entrypoint changes:**

```sh
# Start sshd before OpenCode
/usr/sbin/sshd

# Existing: wait for proxy, harden shell, start opencode serve
```

### Proxy Container

**New: tmux server ownership**

The Proxy starts the tmux server instead of the sandbox.

```sh
# Create tmux session
tmux -S /tmp/tmux/pocketcoder new-session -d -s pocketcoder_session -n main
chmod 777 /tmp/tmux/pocketcoder
```

**New: Poco pane creation via SSH**

After OpenCode passes health check, create the attach window:

```sh
# Wait for OpenCode + sshd
while ! ssh -o ConnectTimeout=2 poco@opencode -p 2222 true 2>/dev/null; do
  sleep 1
done

# Create Poco's tmux window
tmux -S /tmp/tmux/pocketcoder new-window \
  -t pocketcoder_session \
  -n poco \
  "ssh -t poco@opencode -p 2222"
```

The `ForceCommand` on the OpenCode side ensures the SSH session
automatically runs `opencode attach http://localhost:3000 --continue`.

**New: SSH key management**

Generate keypair on first boot, store private key locally, share public
key to OpenCode container via volume.

**New: Pane health monitor**

A background task (tokio or shell loop) that checks if the SSH connection
in the poco window is still alive. If the SSH session drops (OpenCode
container restart, network blip), recreate the window.

```sh
# Simple watchdog (in entrypoint background)
while true; do
  if ! tmux -S /tmp/tmux/pocketcoder list-windows -t pocketcoder_session \
       | grep -q "poco"; then
    # Recreate the window
    tmux -S /tmp/tmux/pocketcoder new-window \
      -t pocketcoder_session -n poco \
      "ssh -t poco@opencode -p 2222"
  fi
  sleep 10
done
```

**No new dependencies.** The Proxy Dockerfile already includes
`openssh-client`, `tmux`, `bash`, and `curl`.

### Sandbox Container

**Removed: tmux server startup**

The sandbox no longer starts the tmux server. It waits for the socket
to appear (created by the Proxy).

```sh
# Replace tmux new-session with:
echo "⏳ Waiting for tmux socket..."
while [ ! -S /tmp/tmux/pocketcoder ]; do
  sleep 1
done
echo "✅ tmux socket found."
```

**New: Poco terminal registration with CAO**

On startup (after tmux socket is available), register Poco's tmux window
as a CAO terminal. This can be done via the CAO API:

```sh
# Register Poco's window with CAO
curl -s -X POST "http://localhost:9889/sessions" \
  -G \
  --data-urlencode "provider=opencode-attach" \
  --data-urlencode "agent_profile=poco" \
  --data-urlencode "session_name=pocketcoder_session" \
  --data-urlencode "delegating_agent_id=poco"
```

Alternatively, the CAO MCP server's `_create_terminal` logic can be
updated to detect and reuse Poco's pre-existing window.

### CAO Changes

**New: OpenCode Attach provider**

A new provider in `cli_agent_orchestrator/providers/` that handles
status detection for the `opencode attach` TUI. The key difference
from the existing `opencode.py` provider is the regex patterns.

The attach TUI displays:
- **IDLE**: Agent name (e.g., "Build"), model name, provider name,
  keybinding hints ("agents", "commands"). No spinner.
- **BUSY/PROCESSING**: Animated spinner (■⬝ blocks), "esc interrupt" text.
- **RETRY**: Error message with retry countdown.

Example status detection patterns:
```python
# IDLE: TUI shows agent name + model + keybinding hints, no spinner
IDLE_PATTERN = r'(agents|commands)\s*$'

# PROCESSING: spinner is visible
PROCESSING_PATTERN = r'esc\s+(interrupt|again to interrupt)'

# RETRY: error with retry countdown
RETRY_PATTERN = r'\[retrying.*attempt #\d+\]'
```

These patterns match what `tmux capture-pane` would return after
stripping ANSI codes from the TUI output.

**Removed: `_notify_brain()` function**

Delete the nudge mechanism from the CAO MCP server entirely.
Inbox delivery is now handled natively by CAO's watchdog via
`tmux send-keys`.

**Removed: nudge call in `send_message`**

The `send_message` tool no longer needs to call `_notify_brain()`
after delivering to the inbox. The watchdog handles delivery timing.

**Removed: `check_inbox` MCP tool (optional)**

With native inbox delivery, Poco doesn't need to manually poll its
inbox. Messages arrive as TUI input automatically. The `check_inbox`
tool can be kept as a fallback or removed.

### Docker Compose Changes

```yaml
services:
  proxy:
    # ... existing config ...
    volumes:
      - proxy_bin:/app/proxy_share
      - tmux_socket:/tmp/tmux
      - ssh_keys:/ssh_keys          # NEW: shared SSH keys
    # ... existing networks (control + execution) ...

  opencode:
    # ... existing config ...
    volumes:
      # ... existing volumes ...
      - ssh_keys:/ssh_keys:ro       # NEW: read SSH public key
    # ... existing networks (memory + control) ...

  sandbox:
    # ... existing config ...
    # No network changes needed
    # tmux_socket volume already shared

volumes:
  # ... existing volumes ...
  ssh_keys:                          # NEW: SSH keypair sharing
```

No network changes required. The Proxy already has access to both
`pocketcoder-control` (reaches OpenCode) and `pocketcoder-execution`
(reaches sandbox via tmux socket).

## Security Analysis

### Attack Surface

| Vector | Risk | Mitigation |
|--------|------|------------|
| SSH daemon in OpenCode container | Low | Key auth only, ForceCommand, dedicated user, single allowed command |
| SSH keypair in shared volume | Low | Private key in Proxy only, public key read-only in OpenCode |
| tmux socket (existing) | Unchanged | Already shared between Proxy and Sandbox |
| Sandbox → Poco pane via send-keys | Low | Same mechanism used for all subagent communication; CAO controls delivery timing |

### What a rogue subagent CAN do

- Send messages to Poco's inbox (by design — this is the feature)
- Read Poco's pane output via `tmux capture-pane` (same as any tmux window)

### What a rogue subagent CANNOT do

- Access OpenCode's private filesystem (different container)
- Execute commands as Poco (shell bridge still requires proxy)
- SSH into the OpenCode container (no access to private key; sandbox is not on control network)
- Kill Poco's serve process (different container; killing the attach TUI in the pane only drops the SSH session, which the Proxy watchdog restarts)
- Bypass the permission gate (proxy shell enforcement unchanged)

### Fault Isolation

| Failure | Impact | Recovery |
|---------|--------|----------|
| Subagent runs `rm -rf /` in sandbox | Poco's serve instance unaffected (different container). Attach TUI SSH session may drop. | Proxy watchdog recreates the tmux window + SSH session |
| OpenCode container restarts | Attach TUI disconnects. Serve instance restarts. | Proxy watchdog detects missing window, recreates SSH session. `--continue` flag resumes the session. |
| Proxy container restarts | tmux server dies. All panes lost. | Proxy recreates tmux session + all windows on boot. Sandbox CAO re-registers terminals. |
| SSH connection drops | Attach TUI exits. Poco serve unaffected. | Proxy watchdog recreates the window within 10s. |

## Migration Path

### Phase 1: Infrastructure (no behavior change)

1. Add sshd to OpenCode container
2. Move tmux server ownership to Proxy
3. Update sandbox entrypoint to wait for tmux socket
4. Add SSH key volume and generation
5. Verify existing functionality unchanged

### Phase 2: Attach Pane

1. Add poco window creation (SSH → attach) to Proxy entrypoint
2. Add pane health watchdog to Proxy
3. Write OpenCode Attach provider for CAO (status detection regex)
4. Register Poco as a CAO terminal on sandbox startup
5. Test: subagent can `send_message` to Poco and it arrives via TUI

### Phase 3: Cleanup

1. Remove `_notify_brain()` from CAO MCP server
2. Remove nudge call from `send_message`
3. Remove/deprecate `prompt_async` nudge path in Proxy `/notify`
4. Remove/deprecate `check_inbox` MCP tool (optional)
5. Update ARCHITECTURE.md and related docs

## Summary

The attach TUI pane serves a single purpose: **inbound message delivery
from subagents to Poco**. It replaces the `_notify_brain()` → `prompt_async`
nudge hack with CAO's native inbox delivery mechanism (`tmux send-keys`).

All outbound execution (Poco → sandbox) continues through the existing
proxy shell bridge. The Relay/PocketBase integration is unchanged.
The linear architecture and zone separation are fully preserved.
