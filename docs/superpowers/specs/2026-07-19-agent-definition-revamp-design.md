# Agent-Definition Revamp — Design Spec

**Date:** 2026-07-19
**Status:** DESIGN — approved for planning. Supersedes `2026-07-18-agent-definition-revamp-DRAFT.md`.
**Depends on:** Legacy Runtime Prune (landed) and the Robust c1↔c2 ACP bridge (in flight). This spec assumes the coordinator shape produced by the bridge plan — `initSession` already performs `initialize → session/new|load → SeedSession → set_session_mode` (see `internal/agent/coordinator/run.go:691`).
**Grounded against:** `services/pocketbase/internal/{hooks,agents,agent}`, migrations `1740000100`/`1748000100`/`1748000500`/`1752000000`, `services/goose/{Dockerfile,entrypoint.sh}`, `coder/acp-go-sdk@v0.13.5`, and Goose config/recipe/ACP docs (`block.github.io/goose`, issues #7596/#7603).

---

## 1. Why this exists

The agent-definition subsystem was built for **OpenCode**: editing config records rendered `/workspace/.opencode/{llm.env,opencode.json}` and restarted the removed `pocketcoder-interface` container. Post-prune those renders still fire but write to a volume nothing reads, and the restart 404s and no-ops. Meanwhile **Goose (c2)** is configured entirely by **process-global env** (`GOOSE_PROVIDER`/`GOOSE_MODEL`/`ANTHROPIC_API_KEY`) with **no per-agent mechanism** wired up.

This revamp re-points agent definition at Goose: PocketBase becomes the source of truth for the agent's model, provider, system prompt, keys, MCP extensions, and tool policy, and delivers them to Goose through the mechanisms Goose actually supports today — while being deliberately shaped so that when Goose ships per-session config (its stated direction, issue #7596), we flip **one component**, not the architecture.

## 2. The controlling constraint (why the design looks the way it does)

Over `goose serve` + ACP, a client **cannot** set per-session: model, provider, system prompt, or a recipe. ACP's `session/new` carries only `cwd` + `mcpServers`. Recipe-over-ACP is an open, unresolved Goose issue (#7596 — recipe application lives only in the legacy HTTP server, not the ACP crate). Per-session model switching via `set_config_option` is advertised but reportedly unreliable at rebinding the backend (#7603).

What ACP **does** allow per session today: `cwd`, `mcpServers` (at `session/new`), and **mode** (`set_session_mode` → auto/approve/smart_approve/chat).

**Consequence:** a single `goose serve` process is fundamentally one agent identity (one model, one provider, one system prompt) for every chat it serves. Genuinely different models/prompts per chat require multiple Goose processes — which we are **not** building, because that is the exact uproot the Goose-side fix will obsolete.

## 3. Design principle

> Build the data model and the coordinator seam as if config were per-session. Bridge today's ACP gap behind a single swappable boundary. When Goose ships per-session config, flip that one boundary — the schema, the resolution path, and the render pipeline stay put.

Two additive constructs carry the principle:

1. **A recipe-shaped agent-definition record** (`poco_configs`) — holds exactly a Goose recipe's worth of fields, so the data never changes when delivery changes.
2. **A capability-gated `ProfileApplier` seam** in the coordinator — the single place that turns a resolved definition into Goose reality.

## 4. Architecture — the applier seam

`initSession` (`run.go:691`) is the one place a resolved agent definition meets Goose (it builds the `session/new` request). The revamp inserts a resolution + application step there.

```
chat ──> resolveProfile(app, chatID) ──> SessionProfile ──> applier.Apply(ctx, conn, sessionID, profile)
                                                                 │
   ┌─────────────────────────────────────────────────────────────┴───────────────────────────────────┐
 GlobalConfigApplier  (today, capability = no per-session config)      PerSessionApplier  (Goose #7596 lands)
 • per-session over ACP: session/new{cwd, mcpServers}, set_session_mode  • passes model/instructions/recipe at
 • global parts (model/provider/prompt/keys) come from the rendered        session/new
   config.yaml (+ keys env) and a container restart — NOT from Apply     • global render becomes default-only bootstrap
```

- `SessionProfile` carries **all** fields (model, provider, instructions, mcpServers, cwd, mode, toolPolicy) regardless of applier. Appliers differ only in *which* fields they can deliver.
- Applier selection is gated on Goose's advertised `initialize` capabilities (checked once per dial). Today that always resolves to `GlobalConfigApplier`; `PerSessionApplier` ships as a stub behind the gate so the flip is a capability flip, not a rewrite.

### 4.1 What is live now vs. inert (be honest)

| Field | Delivery today | When live per-chat |
| --- | --- | --- |
| `mcpServers` | `session/new` per chat | **now** |
| `cwd` (workspace) | `session/new` per chat | **now** |
| `mode` | `set_session_mode` per chat | **now** |
| model / provider | global `config.yaml` + restart | now (global); per-chat when #7596 lands |
| system prompt | global `config.yaml`/instructions + restart | now (global); per-chat when #7596 lands |
| provider keys | global keys env-file (sourced on restart) | now (global) |

A chat set to a non-default agent gets that agent's `mcpServers`/`cwd`/`mode` today, but the **global default's** model + system prompt until Goose per-session lands. This is the one documented leak; the UI should label per-chat model/prompt as "follows workspace default for now."

## 5. Data model

`poco_configs` becomes the canonical, recipe-shaped agent definition. Most fields already exist.

**Keep / start using (currently read by nothing):**
- `harness_model` → `harness_models.harness_model_id` + `models.provider` (model + provider)
- `system_prompt` → `prompts.body` (instructions)
- `acp_mcp_servers` (JSON) → Goose `extensions` / ACP `mcpServers`
- `workspace_folders` (JSON) → `cwd`
- `is_default` (selects which record drives the global `config.yaml`)

**Add:**
- `poco_configs.mode` — enum `auto | approve | smart_approve | chat`, default `approve`. Per-agent; delivered per-chat via `set_session_mode` today. (Replaces the coordinator's hardcoded `"approve"` at `run.go:725`.)

**Keep as-is, now consumed by the Goose permission renderer:**
- `tool_permissions` (`tool`, `pattern`, `action ∈ allow|ask|deny`, `active`, global or per-`poco_config`).

**Chat linkage (already present):**
- `chats.poco_config`, `chats.harness_model_override` → inputs to `resolveProfile`.

**Retired schema (migration):** legacy `ai_agents`/`ai_prompts`/`ai_models`, `llm_keys`/`model_selection`/`llm_providers`, `sandbox_agents`/`sandbox_configs` stay dropped/dormant per the prune; no new drops are required by this spec beyond removing dead code. `harnesses`/`models`/`harness_auth`/`skills` remain defined for future use.

## 6. Render pipeline (replaces the OpenCode renders)

### 6.1 New pure package `internal/gooseconfig/` (no I/O — golden-testable)
- `config.go` — default `poco_config` (+ its `harness_model`, `system_prompt`, `acp_mcp_servers`) → a `config.yaml` document: `GOOSE_PROVIDER`, `GOOSE_MODEL`, `GOOSE_MODE`, and an `extensions:` block. Marshals to YAML.
- `keys.go` — `provider_keys.env_vars` (JSON, all rows) → `KEY=VALUE` env file. **This file is the only place secrets live; it is never returned to any client.**
- `permissions.go` — `tool_permissions` (active) → per-extension `available_tools` allowlist + a mode nudge, per the mapping in §7. Returns the merged config plus a list of dropped `ask` rules for logging.

### 6.2 New hook `internal/hooks/goose_config.go`
Watches `poco_configs`, `provider_keys`, `tool_permissions`, `harness_models`, `prompts`; on change renders `config.yaml` + `keys.env` into the shared config volume, then `renderAndRestart(prefix, render, GooseContainer, e)`.

Reuses `renderAndRestart`/`restartContainer` unchanged (`helpers.go:35`, `docker.go`). Introduces `GooseContainer = "pocketcoder-goose"`; `PocoContainer` is removed.

### 6.3 Retired code
- `hooks/llm.go` render of `/workspace/.opencode/llm.env` → replaced by `gooseconfig.keys`.
- `hooks/tool_permissions.go` render of `/workspace/.opencode/opencode.json` → replaced by `gooseconfig.config` + `gooseconfig.permissions`.
- `agents/bundler.go` `GetAgentBundle`/`UpdateAgentConfig` (markdown-frontmatter bundle into `poco_configs.config`) and the `agents.go` hook that calls it → removed; `poco_configs.config` is no longer written. (If any consumer still reads `config`, it is dropped in the same change.)
- `PocoContainer = "pocketcoder-interface"` and both restarts targeting it.

## 7. Tool-policy mapping (rich rows → Goose, lossy but documented)

Goose has no per-tool allow/ask/deny. Mapping from `tool_permissions`:

| `tool_permissions.action` | Goose effect |
| --- | --- |
| `allow(tool)` | add `tool` to that extension's `available_tools` allowlist |
| `deny(tool)` | ensure `tool` is excluded from `available_tools` |
| `ask(tool)` | **no per-tool Goose equivalent** — dropped from the allowlist render and **logged**; governance falls to the global `mode` |

Rules:
- If an extension has **any** `allow`/`deny` rows, its `available_tools` is rendered as the explicit allow-set minus deny-set (Goose: non-empty allowlist = only those tools). If it has none, `available_tools` is omitted (Goose default = all tools).
- Per-tool `ask` cannot be expressed; the renderer emits a `log.Printf` naming each dropped `ask(tool)` so the degradation is visible, never silent.
- The coarse per-agent `mode` (§5) remains the real runtime gate; runtime HITL approvals continue to flow over ACP unchanged.

## 8. Coordinator changes

- New `internal/agent/coordinator/profile.go`:
  - `type SessionProfile struct { Model, Provider, Instructions, Cwd string; Mode acpsdk.SessionModeId; McpServers []acpsdk.McpServer; ... }`
  - `func resolveProfile(app core.App, chatID string) (SessionProfile, error)` — reads the chat's `poco_config` (or default), applies `harness_model_override`, expands relations, parses `acp_mcp_servers`/`workspace_folders`.
  - `type ProfileApplier interface { Apply(ctx, conn acp.Conn, sessionID string, p SessionProfile) error }`
  - `GlobalConfigApplier` (impl now): sets `cwd`/`mcpServers` at `session/new` and `mode` via `set_session_mode`; treats model/provider/prompt as satisfied out-of-band by the render.
  - `PerSessionApplier` (stub behind capability gate).
- `initSession` (`run.go:691`): replace the hardcoded empty `McpServers` and `ModeId: "approve"` with values from the resolved profile via the selected applier. `SeedSession` and orphan compensation stay as the bridge plan built them.

## 9. Infra (compose + entrypoint)

- Shared volume `goose_config` mounted into both `pocketbase` (writable) and `goose` (read). Goose reads its config from this volume via `XDG_CONFIG_HOME=/goose-config` → `/goose-config/goose/config.yaml`.
- `services/goose/entrypoint.sh`: before `exec goose serve`, `if [ -f /goose-config/keys.env ]; then set -a; . /goose-config/keys.env; set +a; fi` so a restart re-reads app-managed keys. The existing `GOOSE_SERVER__SECRET_KEY`/provider validation is preserved.
- Docker-proxy restart retargeted to `pocketcoder-goose` (already reachable via the write proxy; only the name changes).

## 10. Security invariants (unchanged, restated)

1. `GOOSE_SERVER__SECRET_KEY` and provider API keys **never** appear in any response to Flutter/browser. Keys live only in the rendered `keys.env` on the shared volume, sourced by the goose entrypoint.
2. Goose has **no** network path to PocketBase's DB and no PocketBase token — this spec adds only a shared **file** volume, not a network channel.
3. The renderer writes `config.yaml`/`keys.env` with `0600` (matching the retired renders).

## 11. Testing (TDD)

- **Renderers** (`internal/gooseconfig/*_test.go`): golden-file tests — `poco_config` + relations fixtures → expected `config.yaml`/`keys.env`; explicit cases for the lossy map (`deny`→exclude, `ask`→dropped+logged, no-rows→omit allowlist), multi-`provider_keys` merge, and default-selection.
- **Coordinator** (`coordinator/profile_test.go`): fake `ProfileApplier` + fake `acp.Conn` assert the resolved profile reaches `Apply` with the right `mcpServers`/`cwd`/`mode`; a capability-gate test asserts `GlobalConfigApplier` is selected under today's advertised capabilities.
- **Hook** (`hooks/goose_config_test.go`): a `poco_configs` update triggers a render to the configured path and a restart call (restart faked/observed).

## 12. Out of scope (separate specs)

- **Cron-on-c1 rewire** (`2026-07-18-cron-on-c1-rewire-DRAFT.md`) — independent; cron drives a coordinator run, unaffected by this render pipeline.
- **Multi-process / true per-chat model** — deliberately not built; it is the Goose-side unlock the applier seam waits for.

## 13. Verify against the pinned Goose version (do NOT assume)

1. Goose config-file location and whether `XDG_CONFIG_HOME` is honored by our pinned image (v1.43.0 build); adjust the volume mount path if not.
2. Secret delivery with `GOOSE_DISABLE_KEYRING=1` — confirm keys are read from env (sourced `keys.env`) and not a keyring/secrets file; if Goose expects a secrets file, render that instead.
3. Which session config options / modes the ACP server advertises in our build (drives the capability gate and the `mode` id values).

## 14. Module structure summary

```
internal/gooseconfig/            NEW — pure renderers (config.yaml, keys.env, permissions), golden-tested
  config.go  keys.go  permissions.go
internal/hooks/goose_config.go   NEW — watch config collections → render → renderAndRestart(GooseContainer)
internal/hooks/helpers.go        MODIFY — GooseContainer const; remove PocoContainer
internal/hooks/llm.go            REMOVE OpenCode render (superseded by gooseconfig.keys)
internal/hooks/tool_permissions.go REMOVE opencode.json render (superseded by gooseconfig.config/permissions)
internal/hooks/agents.go         REMOVE bundle hook
internal/agents/bundler.go       REMOVE GetAgentBundle/UpdateAgentConfig
internal/agent/coordinator/profile.go  NEW — SessionProfile, resolveProfile, ProfileApplier, GlobalConfigApplier, PerSessionApplier(stub)
internal/agent/coordinator/run.go      MODIFY initSession — apply resolved profile via applier
migrations/                      NEW — add poco_configs.mode enum
services/goose/entrypoint.sh     MODIFY — source /goose-config/keys.env before serve
docker-compose.yml               MODIFY — goose_config shared volume; XDG_CONFIG_HOME on goose
```
