# Network Security Audit — PocketCoder Docker Compose

_Audited: 2026-02-28._

> [!IMPORTANT]
> **Updated after full matrix test:** The initial audit reported several "violations" that were
> false positives caused by the `pocketcoder-shell` proxy routing all opencode container commands
> through the sandbox invisible to the investigator. After fixing the test methodology
> (script: `scripts/network_matrix_test.py`), the result was **0 security leaks**.
> Docker isolation via DNS scoping is working correctly.
> The sections below are preserved for educational value about Docker's isolation model.

---

## Why Docker "Isolation" Is Weaker Than It Looks

### The Key Misunderstanding

Docker's separate bridge networks are **not firewalls**. They provide:
- ✅ **Service discovery scope** — DNS only resolves names on shared networks
- ❌ **NOT packet-level isolation** — Inter-bridge routing is enabled by default on the Docker host kernel

When you have multiple bridge networks (`pocketcoder-control`, `pocketcoder-tools`, etc.), all of 
those bridges exist in the same Linux kernel routing table on the Docker host. Without an explicit 
`iptables DROP` rule between subnets, packets can flow freely across bridges. Docker Desktop on 
Mac uses a LinuxKit VM but this behavior is preserved.

### DNS Scoping (the one thing that DOES work)

Docker's embedded DNS (`127.0.0.11`) only responds with container IPs for other containers that 
**share at least one common network**. If two containers share no network, `getent hosts 
<name>` returns `NXDOMAIN`. This is the only actual isolation Docker bridge networks provide 
by default.

---

## Actual Network Topology (Verified)

```
Networks and member containers (as defined):

pocketcoder-relay:    pocketbase, opencode
pocketcoder-control:  opencode, sandbox
pocketcoder-tools:    sandbox, mcp-gateway, n8n
pocketcoder-docker:   pocketbase, mcp-gateway, docker-socket-proxy-write
pocketcoder-dashboard: pocketbase, sqlpage
```

### DNS Reachability Matrix (verified via `getent hosts`)

| From ↓ / To → | docker-proxy-write | pocketbase | mcp-gateway | opencode | sandbox | n8n |
|---|---|---|---|---|---|---|
| **sandbox**  | ❌ NO DNS | ❌ NO DNS | ✅ RESOLVES | ✅ RESOLVES | — | ✅ RESOLVES |
| **opencode** | ❌ NO DNS | ❌ NO DNS | ✅ RESOLVES | — | ✅ RESOLVES | ✅ RESOLVES |
| **mcp-gateway** | ✅ RESOLVES | ✅ RESOLVES | — | ❌ NO DNS | ❌ NO DNS | ✅ RESOLVES |

### TCP Reachability Matrix (verified via socket connect)

| From ↓ / To → | mcp-gateway:8811 | opencode:3000 |
|---|---|---|
| **sandbox**  | ✅ OPEN | ✅ OPEN |
| **opencode** | ✅ OPEN (!) | — |

---

## Current Threat Map

### 🔴 CRITICAL: MCP Gateway Has `/var/run/docker.sock` Mounted Directly

```yaml
mcp-gateway:
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro  # ← RAW SOCKET
```

The `mcp-gateway` mounts the **raw Docker socket** (read-only, but still dangerous). Any 
container that can reach the `mcp-gateway` endpoint can potentially exploit this via:
1. Asking the gateway to spawn a privileged MCP tool container
2. The gateway uses the socket to `docker run` with arbitrary flags

**Who can reach mcp-gateway?** Sandbox (DNS + TCP confirmed ✅) and opencode (DNS + TCP ✅).

### 🟠 HIGH: Sandbox Can Reach OpenCode's Control Plane

Sandbox resolves and TCP-connects to `opencode:3000`. The OpenCode server exposes:
- `/api/session/*` — session management
- `/api/ai` — send arbitrary messages to the AI

A compromised sandbox agent could inject instructions directly into Poco's reasoning stream.

### 🟡 MEDIUM: OpenCode Can Reach MCP Gateway Directly

Despite being on separate networks, opencode resolves `mcp-gateway → 172.21.0.4` and can 
TCP-connect. The config bleed (sandbox `opencode.json` loaded by opencode container) means 
Poco actively opens an MCP connection to the gateway with `"*": "allow"` permissions.

### 🟢 CONTAINED: Docker Socket Proxy Properly Isolated

The `docker-socket-proxy-write` has NO DNS from sandbox or opencode — they cannot resolve its 
hostname. This is the one isolation that works correctly because it shares no network with either.
PocketBase is correctly the only consumer through the `pocketcoder-docker` network.

---

## Root Causes

### 1. No `enable_icc: false` on any network

All networks are defined as plain `driver: bridge` with no options. This means all bridges 
share kernel routing and can talk to each other at the IP level once DNS resolves.

### 2. `mcp-gateway` bridges `pocketcoder-tools` and `pocketcoder-docker`

The gateway is the **bridge** between the AI tools world and the Docker control plane. It sits 
on both networks, giving it (and anything that can reach it) a path to Docker operations.

### 3. Config volume contamination

The opencode container reads the sandbox's `opencode.json` (which contains the `mcp-gateway` 
MCP connection), giving Poco unintended gateway access without any Gatekeeper approval.

---

## Fixes (Prioritized)

### Fix 1 (CRITICAL): Remove Raw Docker Socket from MCP Gateway

The gateway currently mounts `/var/run/docker.sock:ro`. Switch to the socket proxy:

```yaml
# docker-compose.yml

# Add a READ-ONLY socket proxy for the mcp-gateway
docker-socket-proxy-mcp:
  image: tecnativa/docker-socket-proxy:latest
  container_name: pocketcoder-docker-proxy-mcp
  environment:
    - CONTAINERS=1   # Gateway needs to spawn/manage tool containers
    - IMAGES=1       # Gateway needs to pull tool images
    - POST=1         # Allow container create/start
    - EXEC=0         # No exec into containers
    - NETWORKS=0
    - VOLUMES=0
    - BUILD=0
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
  networks:
    - pocketcoder-docker   # Only accessible from docker network
  restart: unless-stopped

mcp-gateway:
  environment:
    - DOCKER_HOST=tcp://docker-socket-proxy-mcp:2375   # Use proxy, not raw socket
  volumes:
    # REMOVE: - /var/run/docker.sock:/var/run/docker.sock:ro
    - ./services/mcp-gateway/config:/root/.docker/mcp
```

### Fix 2 (HIGH): Enforce ICC Isolation on All Networks

```yaml
networks:
  pocketcoder-relay:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.enable_icc: "false"
  pocketcoder-control:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.enable_icc: "false"
  pocketcoder-tools:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.enable_icc: "false"
  pocketcoder-docker:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.enable_icc: "false"
  pocketcoder-dashboard:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.enable_icc: "false"
```

> ⚠️ This will break ALL inter-container communication until you test every connection. Every link 
> you need must be on a shared network. With ICC disabled, sharing a network is the ONLY way to 
> communicate (which is what was intended all along).

### Fix 3 (MEDIUM): Fix the Config Bleed

The opencode container accidentally reads the sandbox's `opencode.json`. Two options:

**Option A (Quickest):** Remove the `mcp-gateway` block from the sandbox `opencode.json` 
and instead add it only where needed via a separate config path.

**Option B (Correct):** Do not share the workspace volume between opencode and sandbox for 
`.opencode/` config. Give each container its own isolated config path.

In `docker-compose.yml`, change the sandbox mount:
```yaml
sandbox:
  volumes:
    # REMOVE: - ./services/opencode:/workspace/.opencode  ← This leaks opencode config into sandbox's workspace
    - sandbox_workspace:/workspace   # Give sandbox its own workspace
    - ./services/sandbox/opencode.json:/root/.config/opencode/opencode.json:ro
```

### Fix 4 (LOW): Scope OpenCode → Sandbox Communication

The sandbox should not be reachable from opencode on port 3000 (OpenCode's own server). Consider 
adding an explicit `ALLOW` for only the ports that are needed:
- `sandbox:3001` (Rust proxy exec endpoint — needed by Poco's bash tool)
- `sandbox:9888` (CAO MCP SSE — needed by Poco's MCP client)
- Block all other sandbox ports from opencode reach

---

## Why Docker Does This

Docker's design philosophy prioritizes **developer convenience** over **security by default** for 
local development scenarios. The original design assumption was:

> "If containers are on separate networks, they can't see each other via service discovery (DNS). That's enough."

The inter-bridge routing behavior exists because Docker runs bridges on the host kernel, and 
the Linux kernel routes between subnets by default. Docker does not insert DROP rules between 
its own bridge subnets because:

1. It would break common patterns like "containers on different stacks communicating by IP"
2. It would require Docker to own the kernel routing table more aggressively
3. `enable_icc` exists for those who need strict isolation, but it's opt-in

**For production deployments**, containers handling AI agents with tool access (especially to Docker 
itself) should be hardened with `enable_icc: false` plus explicit firewall allow-lists.

---

## Quick Verification Commands

```bash
# Test if sandbox can reach docker proxy (SHOULD be NO DNS):
docker exec pocketcoder-sandbox python3 -c "import socket; print(socket.gethostbyname('docker-socket-proxy-write'))"
# Expected: socket.gaierror -> GOOD (isolated)

# Test if sandbox can reach mcp-gateway (currently YES):
docker exec pocketcoder-sandbox python3 -c "import socket; print(socket.gethostbyname('mcp-gateway'))"
# Expected after fix: socket.gaierror

# Test if opencode can reach mcp-gateway (currently YES):
docker exec pocketcoder-opencode /bin/sh -c "getent hosts mcp-gateway"
# Expected after fix: empty (after config bleed is fixed)
```
