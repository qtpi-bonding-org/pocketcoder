# Agent Identity Audit — opencode vs sandbox containers

_Audit date: 2026-02-28. Pre-change snapshot before making any cleanups._

---

## Volume Mounts Side-by-Side

| Volume / Path | opencode container | sandbox container | Overlap? |
|---|---|---|---|
| `opencode_workspace` | `/workspace` | `/workspace` | ⚠️ **SHARED** |
| `./services/opencode` | `/workspace/.opencode` | `/workspace/.opencode` | ⚠️ **SHARED** (same dir, same dest) |
| `./services/opencode/opencode.json` | `/root/.config/opencode/opencode.json` :ro | — | opencode only |
| `./services/sandbox/opencode.json` | — | `/root/.config/opencode/opencode.json` :ro | sandbox only ✓ |
| `opencode_data` | `/root/.local/share/opencode` | — | opencode only |
| `./services/mcp-gateway/config` | `/mcp_config` :ro | — | opencode only |
| `shell_bridge` | `/shell_bridge` | `/app/shell_bridge` | ⚠️ SHARED (differing path) |
| `./services/sandbox/cao/src` | — | `/app/cao/src` | sandbox only ✓ |
| `./services/sandbox/agents/subagents` | — | `/root/.aws/cli-agent-orchestrator/agent-store` | sandbox only ✓ |
| `cao_db` | — | `/root/.aws/cli-agent-orchestrator/db` | sandbox only ✓ |
| `./scripts/debug` | — | `/workspace/debug` | sandbox only ✓ |

---

## Key Overlap: `./services/opencode:/workspace/.opencode`

Both containers mount the **same host directory** to the **same container path**. This means:

- In the opencode container: `/workspace/.opencode/opencode.json` = Poco's config
- In the sandbox container: `/workspace/.opencode/opencode.json` = also Poco's config (!)

OpenCode discovery reads configs from:
1. `~/.config/opencode/opencode.json` (user-level)
2. `./.opencode/opencode.json` (project-level, relative to working dir)

The sandbox opencode process (running in `/workspace`) reads **both**:
- `/root/.config/opencode/opencode.json` → sandbox config ✓ (mcp-gateway, `"*": allow`)
- `/workspace/.opencode/opencode.json` → **Poco's config** ← config bleed

OpenCode merges both. The sandbox agent ends up with a merged config of both Poco and sandbox.
In practice this is benign (sandbox is already more permissive) but it's conceptually messy.

---

## opencode container — Config Audit (`services/opencode/opencode.json`)

### Agent: `poco`
| Property | Value | Assessment |
|---|---|---|
| `mode` | `primary` | ✓ |
| `tools` | write, edit, bash, read, grep, glob, list, skill, cao_* | ✓ correct |
| `permission.bash` | `ask` | ✓ gated |
| `permission.edit` | `ask` | ✓ gated |
| `permission.cao_*` | `ask` | ✓ ask before delegating |

### Global permissions

| Key | Value | Assessment |
|---|---|---|
| `mcp_catalog` | `allow` | ✓ |
| `mcp_status` | `allow` | ✓ |
| `mcp_request` | `ask` | ✓ |
| `mcp-gateway_*` | `allow` | ⚠️ **Was added during debugging session — should be removed** |
| `*` | `ask` | ✓ safe default |

### MCP Servers
| Name | URL | Assessment |
|---|---|---|
| `cao` | `http://sandbox:9888/sse` | ✓ correct — Poco delegates to sandbox via CAO |

**Problem:** The `mcp-gateway_*: allow` rule was added during our debugging session and should be
removed. Even if Poco can't actually reach mcp-gateway (confirmed by network test), this rule left
in is misleading and could cause confusion.

---

## sandbox container — Config Audit (`services/sandbox/opencode.json`)

### Agent: `developer`
| Property | Value | Assessment |
|---|---|---|
| `mode` | `primary` | ✓ |
| `tools` | `"*": true` | ✓ correct — unrestricted |
| `permission` | `"*": allow` | ✓ correct — no gates |
| `prompt` | "You are a developer agent... unrestricted execution..." | ⚠️ **Too sparse — see below** |

### Global permissions
| Key | Value | Assessment |
|---|---|---|
| `*` | `allow` | ✓ correct for sandbox |

### MCP Servers
| Name | URL | Assessment |
|---|---|---|
| `mcp-gateway` | `http://mcp-gateway:8811/sse` | ✓ correct |

**Problem:** The `developer` agent prompt is too sparse. Issues observed in practice:
- Agent didn't know API keys are pre-configured → tried to pass them in mcp-config-set → secret scanner rejected → wasted retry cycles
- Agent didn't know "0 tools added" after `mcp-add` is normal → expressed confusion
- No guidance on the mcp-gateway tool naming pattern or how dynamic tools work

---

## Shell Hijacking — The Invisible Proxy

The opencode container entrypoint (`opencode_entrypoint.sh`) does:
```sh
ln -sf /usr/local/bin/pocketcoder-shell /bin/sh
```
This replaces `/bin/sh` with the Rust proxy binary. **Every shell invocation in the opencode
container is forwarded to the sandbox.** This is intentional by design — Poco's "bash" tool
runs in the sandbox — but it makes the opencode container's shell untrustworthy for inspection.

**Implication for debugging:** Never trust `docker exec pocketcoder-opencode sh -c "..."`.
Use `docker inspect` or probe from other containers instead.

---

## Summary of Issues to Fix

### 🔴 Must fix
1. **Remove `mcp-gateway_*: allow` from `services/opencode/opencode.json`** — debugging artifact, misleading

### 🟡 Should fix
2. **Remove `./services/opencode:/workspace/.opencode` from sandbox volumes** — config bleed, sandbox reads Poco's project config
3. **Improve sandbox `developer` agent prompt** — tell it: API keys are pre-configured via secrets, `mcp-add` returning "0 tools" is normal, `mcp-config-set` rejects secrets, call tools directly not via `mcp-exec`

### 🟢 Nice to have
4. **Give the sandbox agent a better name** — `developer` is generic; consider `sandbox` or `autonomy` to be explicit about the context
5. **Poco.md agent file** — currently just `{"tools": {"write": true, ...}}`, a stub; consider whether it should be expanded or removed since opencode.json already defines Poco fully

---

## What NOT to Change

- `./services/opencode/opencode.json:/root/.config/opencode/opencode.json:ro` — correct, opencode reads Poco's config at the user-level path ✓
- `./services/sandbox/opencode.json:/root/.config/opencode/opencode.json:ro` — correct, sandbox reads sandbox config ✓
- `opencode_workspace:/workspace` shared — both containers need access to the working files; this is intentional
- sandbox `"*": allow` permissions — correct, sandbox agents should be unrestricted
- mcp-gateway connection in sandbox config — correct, sandbox is on pocketcoder-tools and CAN reach it
