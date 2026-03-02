# PocketCoder Architecture Rules & Assessment

## The One Rule

**Flutter only talks to PocketBase. Everything else is a consequence of that.**

PocketBase is the single source of truth. The Flutter client never calls OpenCode, never hits the sandbox, never touches Docker. It reads and writes PocketBase collections. Everything downstream reacts.

---

## The Two Patterns

Every feature in PocketCoder falls into one of two patterns based on a simple question: **does it change OpenCode's runtime behavior, or its environment?**

### Pattern 1: Runtime Behavior → SDK via Interface

**When**: The action affects what OpenCode does *right now* — sending a message, switching a model mid-session, approving a permission, reading streaming output.

**Path**: `Flutter → PocketBase collection → Interface subscription → OpenCode SDK call`

**No restart. No file writes. Immediate.**

The interface service watches PocketBase collections via realtime subscriptions and translates record changes into OpenCode SDK calls. The reverse path (OpenCode events → PocketBase records) works the same way through the event pump.

**Examples**:
| User action | PB collection | Interface SDK call |
|-------------|--------------|-------------------|
| Send message | `messages` (create) | `oc.session.prompt()` |
| Approve permission | `permissions` (update) | `oc.postSessionIdPermissionsPermissionId()` |
| Switch model (one chat) | `llm_config` (create, with `chat`) | `oc.session.command({ command: 'model' })` |
| Set default model | `llm_config` (create, no `chat`) | `oc.config.update({ model })` |

**And the reverse** (OpenCode → Flutter):
| OpenCode event | Interface action | PB collection |
|---------------|-----------------|---------------|
| `message.part.updated` | Upsert streaming parts | `messages` (update) |
| `message.updated` | Set completion status | `messages` (update) |
| `permission.updated` | Create permission record | `permissions` (create) |

**Rule**: If you can do it with an SDK call, do it with an SDK call. Don't restart containers for runtime changes.

### Pattern 2: Environment/Config → Go Hook + Restart

**When**: The action changes what OpenCode *starts with* — API keys, environment variables, config files that are read at boot time.

**Path**: `Flutter → PocketBase collection → Go hook → write file to shared volume → restart container via Docker Socket Proxy`

**Restart required. Takes ~15-30s. Use sparingly.**

Go hooks in PocketBase listen for collection changes, render config files to shared Docker volumes, and restart the affected container so it picks up the new environment.

**Examples**:
| User action | PB collection | Go hook | File written | Container restarted |
|-------------|--------------|---------|-------------|-------------------|
| Save API key | `llm_keys` | `llm.go` | `/workspace/.opencode/llm.env` + `/llm_keys/llm.env` | OpenCode |
| Delete API key | `llm_keys` | `llm.go` | `/workspace/.opencode/llm.env` + `/llm_keys/llm.env` | OpenCode |
| Approve MCP server | `mcp_servers` | `mcp.go` | `/mcp_config/docker-mcp.yaml` + `mcp.env` | MCP Gateway |
| Revoke MCP server | `mcp_servers` | `mcp.go` | `/mcp_config/docker-mcp.yaml` + `mcp.env` | MCP Gateway |

**Rule**: If it requires a process restart to take effect (env vars, config files), use a Go hook. The hook writes files, then restarts.

### How to Decide

```
Does OpenCode need to restart for this to work?
├── No  → Pattern 1 (SDK via Interface)
│         Write to PB collection, let interface subscription handle it
└── Yes → Pattern 2 (Go Hook + Restart)
          Write to PB collection, let Go hook render file + restart
```

---

## The Third Pattern: Sync (Read-Only)

There's a third pattern for populating reference data that doesn't trigger any action:

**Path**: `External source → Interface (on schedule) → PocketBase collection → Flutter reads`

**Example**: Provider sync. The interface calls `oc.provider.list()` on startup and daily, upserts the results into `llm_providers`. Flutter reads this collection to show available providers and models. No hook, no restart, just data flowing into PB for the UI to display.

---

## Network Trust Boundaries

The architecture enforces trust through Docker network isolation:

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│   Flutter    │────▶│  PocketBase   │────▶│  Interface   │
│  (outside)   │     │  (hub)        │     │  (bridge)    │
└─────────────┘     └──────┬───────┘     └──────┬───────┘
                           │                     │
                    pocketcoder-docker     pocketcoder-opencode-sdk
                           │                     │
                    ┌──────▼───────┐     ┌──────▼───────┐
                    │ Docker Proxy  │     │   OpenCode   │
                    │ (write)       │     │   (brain)    │
                    └──────────────┘     └──────┬───────┘
                                                │
                                         pocketcoder-control
                                                │
                                         ┌──────▼───────┐
                                         │   Sandbox     │
                                         │  (execution)  │
                                         └──────┬───────┘
                                                │
                                         pocketcoder-tools
                                                │
                                         ┌──────▼───────┐
                                         │ MCP Gateway   │
                                         │  (tools)      │
                                         └──────────────┘
```

**Key separations**:
- OpenCode has no Docker socket (can't restart containers, can't spawn processes outside sandbox)
- Sandbox has no PocketBase access (can't read user data, can't modify permissions)
- MCP Gateway has read-only Docker socket (can spawn tool containers but nothing else)
- PocketBase has write Docker socket but only for container restart operations

---

## Conventions

### Collection Naming
- Snake_case: `llm_keys`, `mcp_servers`, `llm_config`
- Collection IDs prefixed with `pc_`: `pc_llm_keys`, `pc_chats`

### Go Hook Structure
Follow `mcp.go` as the canonical pattern:
1. `RegisterXxxHooks(app core.App)` — registers all hooks + initial render on `OnServe`
2. `renderXxx(app)` — queries collection, writes file to shared volume
3. `restartXxx()` — calls Docker Socket Proxy to restart target container
4. Hook handler calls render, then restart, then `e.Next()`
5. Log with emoji prefix for the subsystem: `🔑 [LLM]`, `🔌 [MCP]`

### Interface Subscription Structure
Follow `startCommandPump()` as the canonical pattern:
1. Subscribe to collection with `pb.collection('xxx').subscribe('*', ...)`
2. Filter by `e.action` (`create`, `update`)
3. Call async handler function
4. Add `unsubscribe` in `setupGracefulShutdown()`

### Access Rules
- Owner-only data (keys, config): `user = @request.auth.id || @request.auth.role = 'admin'`
- Agent-writable catalogs: `@request.auth.role = 'agent' || @request.auth.role = 'admin'`
- Any authenticated reader: `@request.auth.id != ''`

---

## Architectural Assessment

### What's Strong

**The PocketBase-as-hub design is the right call.** Making PocketBase the single gateway for Flutter means you get auth, realtime subscriptions, REST API, and SQLite persistence from one dependency. The interface service is stateless — if it crashes, it reconnects and resumes. All state survives in PB. This is simple in the best way.

**The SDK integration through the interface service is clean.** The event pump and command pump are a good abstraction. They're symmetric (OpenCode→PB, PB→OpenCode), the message locking prevents streaming race conditions, and the session cache avoids redundant lookups. The scrubbing of telemetry fields before persisting to PB shows thoughtful data hygiene.

**The hook/restart pattern for environment changes is pragmatic.** You could have built a custom IPC channel to hot-reload API keys into OpenCode, but writing an env file and restarting is simpler, debuggable (you can cat the file), and uses infrastructure that already exists (Docker Socket Proxy). The 15-second restart cost is acceptable for something users do rarely.

**Network isolation is real security, not theater.** OpenCode can't reach the Docker socket. The sandbox can't reach PocketBase. The MCP gateway has read-only Docker access. These are hard boundaries enforced by Docker networking, not just conventions. The Rust shell proxy adds defense-in-depth — even if OpenCode is compromised, commands go through a validation layer before reaching tmux.

**The permission system is genuinely zero-trust.** Every tool execution creates an audit record *before* execution. The Flutter user approves or denies. The permission flows through PocketBase (so Flutter sees it) and back through the interface to OpenCode. There's no bypass path.

### What to Watch

**Single-machine, multi-user with shared keys.** One OpenCode instance, one workspace volume. Multiple PocketBase users (e.g., a family) can each have their own chats and sessions, but `renderLlmEnv` writes ALL users' keys into one flat env file. This means all users on the box share the same pool of API keys. The `llm_keys` collection has a `user` field for ownership, but the rendered output is a union. This is intentional for the "family VPS" model — if you ever needed strict key isolation, you'd need per-user OpenCode instances or a key-proxying layer.

**Sandbox gets LLM keys via shared volume, not container env.** The `llm_keys` Docker volume is mounted read-only at `/llm_keys/` in the sandbox. CAO's OpenCode provider sources `/llm_keys/llm.env` before each `opencode run` invocation — no container restart needed since each run is a fresh subprocess. The sandbox keeps its own `opencode.json` (with different permissions: `"*": "allow"` vs Poco's `"*": "ask"`) and does NOT mount Poco's full `./services/opencode/` directory.

**Provider sync is fire-and-forget.** The `syncProviders()` function runs on startup and daily. If it fails (OpenCode not ready, network blip), there's no retry until the next 24-hour interval. For a mobile app where the user might open it seconds after boot, the providers list could be stale. A retry-on-failure with backoff would be more resilient.

**Container restart is the only recovery mechanism.** If the Go hook fails to restart OpenCode (Docker proxy down, container stuck), there's no retry or health-check-driven recovery. The hook logs the error and moves on. The user would see their key saved in the UI but OpenCode still running with old keys. A periodic reconciliation (compare `llm.env` timestamp against OpenCode's start time) could catch drift.

### Opportunities

**The interface service could expose its own health details.** Right now `/healthz` reports event pump and command pump status. Adding provider sync status, last sync time, and llm_config subscription status would help debugging in production.

**OpenCode's `opencode.json` is still read-only mounted.** The model field in `opencode.json` is `"google/gemini-2.0-flash"` — but now that model switching goes through `oc.config.update()`, this is just the boot default. If users change their default model via `llm_config`, it takes effect at runtime but resets on restart. Consider having the Go hook also update `opencode.json` when the global default changes, so the boot default matches the user's preference.

**The Flutter client can be optimistic.** Since all the backend plumbing is reactive (PB subscriptions → interface → OpenCode), the Flutter UI can write to PB collections and immediately show the expected state. The backend will catch up. This is already how chat messages work (write to `messages`, turn changes to `user`, interface picks it up). The same pattern applies to model switching and key management — no need to wait for confirmation.
