# How the n8n Workflow Was Created — Investigation & Corrected Findings

_Investigated: 2026-02-28. Initially contained several false conclusions due to the
pocketcoder-shell proxy silently rerouting all opencode container shell commands into
the sandbox. Corrected after full network matrix analysis._

---

## TL;DR — The Correct Answer

When we ran `docker compose exec opencode sh -c 'opencode run --agent poco ...'`, we were
**NOT running Poco**. The command was silently forwarded through the Rust proxy into the
sandbox container, where a **sandbox agent** ran it. Docker isolation is working correctly.
Poco has no direct access to the MCP gateway.

---

## ⚠️ The Root Confusion: The Shell Proxy Is Invisible

The opencode container sets `SHELL=/usr/local/bin/pocketcoder-shell`. This means **every**
shell command executed inside the opencode container — including `docker exec opencode sh -c`
— is intercepted by the Rust `pocketcoder` binary and forwarded to the sandbox's Rust axum
server at `http://sandbox:3001/exec`. The sandbox then executes the command in a tmux session.

**Consequence:** Any time we ran `docker exec pocketcoder-opencode /bin/sh -c "..."`, we were
actually reading the sandbox's filesystem, the sandbox's network interfaces, and the sandbox's
config. The tell: `🔥 [Bridge Error]: OPENCODE_SESSION_ID environment variable is not set`
appearing in every single command output.

---

## The Real Flow (What Actually Happened)

```
We ran:
  docker compose exec opencode sh -c 'opencode run --agent poco ...'

Step 1: docker exec runs /bin/sh in the opencode container

Step 2: SHELL=/usr/local/bin/pocketcoder-shell intercepts it
  pocketcoder-shell → POST http://sandbox:3001/exec
          { cmd: "opencode run --agent poco ..." }

Step 3: Sandbox Rust axum server receives the request
  → runs `opencode run --agent poco ...` in the sandbox tmux

Step 4: Sandbox opencode reads /root/.config/opencode/opencode.json
  → this is ./services/sandbox/opencode.json (the SANDBOX config)
  → which declares: mcp-gateway @ http://mcp-gateway:8811/sse

Step 5: Sandbox opencode connects to mcp-gateway
  → sandbox is on pocketcoder-tools network ✓
  → mcp-gateway is on pocketcoder-tools network ✓
  → DNS resolves, TCP connects, SSE established ✓

Step 6: Sandbox agent calls n8n_create_workflow via mcp-gateway
  → workflow created (ID: wPCQA9O2lGyuxVws) ✓
```

This was a **sandbox agent** all along. Not Poco.

---

## Why All Our "Evidence" About Poco Was Wrong

Every command we ran to investigate the opencode container was actually running in the sandbox:

| What we ran | What we thought | What actually happened |
|---|---|---|
| `docker exec opencode cat /root/.config/opencode/opencode.json` | Reading opencode's config | Reading sandbox's config (which has mcp-gateway) |
| `docker exec opencode cat /etc/hosts` | Seeing opencode's IPs | Seeing sandbox's IPs (172.20.x + 172.21.x) |
| `docker exec opencode cat /proc/net/arp` | Opencode's ARP table | Sandbox's ARP table (showing tools-network hosts) |
| `docker exec opencode /bin/sh -c "getent hosts mcp-gateway"` | Testing opencode's DNS | Testing sandbox's DNS (resolves because sandbox shares tools network) |

The container ID `17338a59069f` that appeared in `/etc/hosts` is the **sandbox container**, not opencode.

---

## The Actual Network Security Posture (Correct)

Docker isolation IS working correctly. Verified via the network matrix test (`scripts/network_matrix_test.py`):

**Result: 0 security leaks, 0 broken paths.**

```
pocketcoder-relay:     pocketbase (172.19.0.2), opencode (172.19.0.3)
pocketcoder-control:   opencode (172.20.0.3),   sandbox  (172.20.0.2)
pocketcoder-tools:     sandbox  (172.21.0.3),   n8n      (172.21.0.2),  mcp-gateway (172.21.0.4)
pocketcoder-docker:    pocketbase(172.22.0.2),  mcp-gateway(172.22.0.4), docker-proxy(172.22.0.3)
```

**That isolation holds because Docker DNS is the enforcement mechanism.** If containers don't
share a network, the hostname doesn't resolve, and TCP never starts. You cannot sneak around
this without a shared network — the iptables DOCKER-ISOLATION chains are secondary.

### Opencode (Poco) can only reach:
- `pocketbase:8090` — via pocketcoder-relay ✓ (intended)
- `sandbox:3001/9888/9889` — via pocketcoder-control ✓ (intended)
- Nothing else. mcp-gateway, n8n, docker-proxy → all `NO DNS` from opencode.

### Sandbox can reach:
- `opencode:3000` — via pocketcoder-control ✓ (intended)
- `mcp-gateway:8811` — via pocketcoder-tools ✓ (intended)
- `n8n:5678` — via pocketcoder-tools ✓ (intended)
- NOT pocketbase, NOT docker-proxy-write (no shared network → DNS fails)

---

## What Poco CAN Actually Do (The Intended Architecture)

Poco's actual tool access:
1. **Bash commands** → intercepted by `pocketcoder-shell` → Rust proxy → sandbox tmux
2. **MCP tools (cao_*)** → via SSE to `http://sandbox:9888` (CAO MCP server)
   - `create_terminal` — spin up a new sandbox agent in a tmux window
   - `send_message` — message a running agent
   - `list_workers` — see running agents

Poco does NOT directly use mcp-gateway tools. Poco delegates tasks to sandbox agents via CAO.
Sandbox agents have the mcp-gateway config and can use those tools directly.

---

## How to Correctly Run a Sandbox Agent

Since `docker exec opencode sh -c 'opencode run ...'` actually runs inside the sandbox anyway,
here is what it's equivalent to and the correct way to think about it:

**Equivalent correct invocation** (more explicit):
```bash
docker exec pocketcoder-sandbox opencode run --agent developer "Create an n8n workflow..."
```

The sandbox's opencode.json grants the `developer` agent `"*": "allow"` permissions and has
the `mcp-gateway` MCP connection. This is the intended sandbox agent path.

**Working minimal prompt to create an n8n workflow:**
```
1. Call mcp-add with { "name": "n8n" }
   → "0 tools added" response is NORMAL, continue.
2. Call n8n_create_workflow directly (NOT via mcp-exec) with a 2-node workflow.
   → n8n requires ≥2 nodes or validation fails.
3. Report the workflow ID.
```

**Why the config-set with API key fails:**
The MCP gateway's secret scanner rejects JWT-shaped strings in `mcp-config-set`. The API key
is already pre-loaded in `mcp.env` by the PocketBase relay — you don't need to pass it in the
prompt. Just call `mcp-add` and the container gets the key automatically via the `secrets:`
block in `docker-mcp.yaml`.

---

## Remaining Real Concern: Config Bleed

The `./services/opencode:/workspace/.opencode` volume is shared between opencode and sandbox.
If OpenCode's config discovery ever reads `workspace/.opencode/opencode.json` on the opencode
container, it would only find Poco's config (only `cao`). The sandbox config
(`./services/sandbox/opencode.json`) is correctly mounted only inside the sandbox container.

**This is NOT a live vulnerability** — just a reminder to keep volume mounts clean and not
accidentally cross-mount sandbox config into the opencode container context.

---

## Lessons for Future Debugging

> **Golden Rule:** Never trust a `docker exec pocketcoder-opencode sh -c "..."` result.
> The pocketcoder-shell proxy silently routes it to the sandbox.
> Always check for `🔥 [Bridge Error]` in the output as the tell.

To investigate the opencode container's actual state, use:
```bash
# Safe: bypasses pocketcoder-shell by going to the process directly
docker inspect pocketcoder-opencode
docker network inspect pocketcoder_pocketcoder-relay
docker network inspect pocketcoder_pocketcoder-control
```

To test opencode reachability, test FROM other containers TO opencode, not in reverse:
```bash
docker exec pocketcoder-sandbox bash -c "bash -c 'exec 3<>/dev/tcp/opencode/3000' && echo OPEN"
docker exec pocketcoder-pocketbase sh -c "bash -c 'exec 3<>/dev/tcp/opencode/3000' && echo OPEN"
```
