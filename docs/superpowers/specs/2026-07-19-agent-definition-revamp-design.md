# Agent-Definition Revamp — Design Spec

**Date:** 2026-07-19
**Status:** DESIGN — approved for planning (hardened per Opus review 2026-07-19). Supersedes `2026-07-18-agent-definition-revamp-DRAFT.md`.
**Depends on:** Legacy Runtime Prune (landed) and the Robust c1↔c2 ACP bridge (in flight). This spec assumes the coordinator shape the bridge plan produces — `initSession` performs `initialize → session/new|load → SeedSession → set_session_mode` (`internal/agent/coordinator/run.go`, function `initSession`). Cite by function name, not line: the bridge plan changes `initSession`'s signature.
**Grounded against:** `services/pocketbase/internal/{hooks,agents,agent}`, `services/pocketbase/Dockerfile` (root, no `USER`), migrations `1740000100`/`1748000100`/`1748000200`/`1748000500`/`1752000000`, `services/goose/{Dockerfile,entrypoint.sh}`, `docker-compose.yml`, `coder/acp-go-sdk@v0.13.5` (`types_gen.go`), and Goose config/recipe/ACP docs (`block.github.io/goose`, issues #7596/#7603).

---

## 1. Why this exists

The agent-definition subsystem was built for **OpenCode**: editing config records rendered `/workspace/.opencode/{llm.env,opencode.json}` and restarted the removed `pocketcoder-interface` container. Post-prune those renders still fire but write to a volume nothing reads, and the restart 404s and no-ops. Meanwhile **Goose (c2)** is configured entirely by **process-global env** (`GOOSE_PROVIDER`/`GOOSE_MODEL`/`ANTHROPIC_API_KEY`) with **no per-agent mechanism** wired up.

This revamp re-points agent definition at Goose: PocketBase becomes the source of truth for the agent's model, provider, system prompt, keys, MCP servers, and tool policy, and delivers them to Goose through the mechanisms Goose actually supports today — while being deliberately shaped so that when Goose ships per-session config (its stated direction, issue #7596), we flip **one component**, not the architecture.

## 2. The controlling constraint (why the design looks the way it does)

Over `goose serve` + ACP, a client **cannot** set per-session: model, provider, system prompt, or a recipe. ACP's `session/new` carries only `cwd` + `mcpServers` (+ `additionalDirectories`). Recipe-over-ACP is an open, unresolved Goose issue (#7596 — recipe application lives only in the legacy HTTP server, not the ACP crate). Per-session model switching via `set_config_option` is advertised but reportedly unreliable at rebinding the backend (#7603).

What ACP **does** allow per session today: `cwd`/`additionalDirectories`, `mcpServers` (at `session/new` **and** `session/load`), and **mode** (`set_session_mode`).

**Consequence:** a single `goose serve` process is fundamentally one agent identity (one model, one provider, one system prompt) for every chat it serves. Genuinely different models/prompts per chat require multiple Goose processes — which we are **not** building, because that is the exact uproot the Goose-side fix will obsolete.

## 3. Design principle

> Build the data model and the coordinator seam as if config were per-session. Bridge today's ACP gap behind a single swappable boundary. When Goose ships per-session config, flip that one boundary — the schema, the resolution path, and the render pipeline stay put.

Two additive constructs carry the principle:

1. **A recipe-shaped agent-definition record** (`poco_configs`) — holds exactly a Goose recipe's worth of fields, so the data never changes when delivery changes.
2. **A capability-gated `ProfileApplier` seam** in the coordinator — the single place that turns a resolved definition into Goose reality.

## 4. Architecture — the applier seam

`initSession` is the one place a resolved agent definition meets Goose. Two facts fix the seam's shape (both from Opus review C2):

- `cwd`/`additionalDirectories`/`mcpServers` are **inputs to `session/new` / `session/load`**, which *produce* the `sessionID`. They cannot be delivered by anything that runs *after* the session exists.
- `set_session_mode` is the only per-session call that runs *after* the sessionID exists.

So the seam is split by lifecycle phase, and `initSession` owns request construction while the applier owns the post-create per-session step:

```
chat ──> resolveProfile(app, chatID) ──> SessionProfile
                                            │
   initSession:                             │
     initResp = conn.Initialize(...)        │   (capture the response — needed for the gate)
     applier  = selectApplier(initResp)     │
     req      = NewSession/LoadSession{       ← Cwd, AdditionalDirectories, McpServers from SessionProfile
                  Cwd, AdditionalDirectories, McpServers }
     sessionID = conn.NewSession(req)|LoadSession(req)
     applier.Apply(ctx, conn, sessionID, profile)   ← today: set_session_mode; future: per-session model/prompt
```

- **`SessionProfile`** carries the fields the coordinator needs: model + provider + instructions (for future per-session use and for the render pipeline's default), `Cwd string`, `AdditionalDirectories []string`, `McpServers []acpsdk.McpServer`, `Mode acpsdk.SessionModeId`. It does **not** carry tool policy — that is delivered by the render pipeline (config.yaml `available_tools`), not per session (Opus S7).
- **`initSession`** reads `profile.Cwd`/`AdditionalDirectories`/`McpServers` directly into both the `NewSession` and `LoadSession` requests (both branches carry them — Opus C2).
- **`ProfileApplier`** owns only what runs post-create:
  ```go
  type ProfileApplier interface {
      Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile) error
  }
  ```
  - `GlobalConfigApplier` (impl now): `conn.SetSessionMode(sessionID, p.Mode)`. Model/provider/prompt are satisfied out-of-band by the render pipeline + restart, not by `Apply`.
  - `PerSessionApplier` (stub, behind the gate): additionally applies model/prompt/recipe per session when Goose supports it.
- **Capability gate:** `selectApplier` inspects the captured `InitializeResponse.AgentCapabilities`. **Today there is no SDK field for per-session model/prompt config** (`sessionCapabilities:{}` — #7596 hasn't shipped), so the gate **always** resolves to `GlobalConfigApplier`. This is documented, not a field to hunt for; when the capability is defined the gate flips (Opus S8).

### 4.1 What is live now vs. inert (be honest)

| Field | Delivery today | Live per-chat? |
| --- | --- | --- |
| `mcpServers` | `session/new`/`load` request, built by `initSession` from the profile | **now** |
| `cwd` / `additionalDirectories` | same request | **now** |
| `mode` | `applier.Apply` → `set_session_mode` | **now** |
| model / provider | global `config.yaml` + restart | global now; per-chat when #7596 lands |
| system prompt | **uncertain** — `config.yaml` has no documented global `instructions` key (that is a *recipe* field, and recipes can't load over ACP). Global delivery is conditional on §13.5; if unsupported, the system prompt is **inert** until recipe-over-ACP, same as per-chat model. | verify §13.5 |
| provider keys | global `keys.env` (sourced on restart) | global now |
| `chats.harness_model_override` | **inert** (per-chat model can't apply) | per-chat when #7596 lands |

A chat set to a non-default agent (or with `harness_model_override`) gets that agent's `mcpServers`/`cwd`/`mode` today, but the **global default's** model + system prompt until Goose per-session lands. The UI should label per-chat model/prompt (and `harness_model_override`) as "follows workspace default for now."

## 5. Data model

`poco_configs` becomes the canonical, recipe-shaped agent definition. Most fields exist.

**Keep / start using (currently read by nothing):**
- `harness_model` → two-hop expand `harness_models.harness_model_id` (model string) + `harness_models.model → models.provider` (provider). `resolveProfile` performs this expand.
- `system_prompt` → `prompts.body` (instructions).
- `acp_mcp_servers` (JSON) → per-session ACP `mcpServers` (schema in §5.1).
- `workspace_folders` (JSON array) → `cwd` (first element) + `additionalDirectories` (remainder) (Opus S4).
- `is_default` — selects the record driving the global `config.yaml`; see §5.2 for tie-break.

**Add (provisional — see §13.3):**
- `poco_configs.mode` — enum `auto | approve | smart_approve | chat`, default `approve`. Delivered per-chat via `set_session_mode`. Replaces the coordinator's hardcoded `"approve"`. **The exact mode ids must be confirmed against the advertised session modes of the pinned Goose build before the migration lands** (§13.3); only `approve` is known-good today.

**Drop (this is a real new drop — Opus N1):**
- `poco_configs.config` (`1748000200_poco_config_fields.go`) — the OpenCode markdown bundle field. Its only writers (`agents.go`, `bundler.go`) are removed (§6.3); a migration drops the column (the existing down at `1748000200` mirrors the add). §5's earlier "no new drops" claim was wrong.

**Keep as-is, now consumed by the permission renderer:**
- `tool_permissions` (`tool`, `pattern`, `action ∈ allow|ask|deny`, `active`, global or per-`poco_config`). See §7 for the lossy mapping.

**Chat linkage (already present):** `chats.poco_config`, `chats.harness_model_override` → inputs to `resolveProfile`.

### 5.1 `acp_mcp_servers` JSON schema (Opus C3)

`acpsdk.McpServer` is a discriminated union (`type ∈ stdio|http|sse|acp`), and **http/sse/acp are gated on the agent's advertised `mcp_capabilities`**. To stay within what the pinned Goose build reliably supports, **the render/resolve path supports `stdio` only** in this revamp; `http`/`sse`/`acp` entries are **skipped with a log** and deferred to a follow-up once capability advertisement is confirmed (§13). The stored JSON is an array:

```json
[
  { "type": "stdio", "name": "filesystem",
    "command": "npx", "args": ["-y","@modelcontextprotocol/server-filesystem","/workspace"],
    "env": { "FOO": "bar" } }
]
```

`resolveProfile` parses this into `[]acpsdk.McpServer` (stdio variant). Unknown/unsupported `type` → skip + log. **MCP servers are delivered per-session over ACP only — they are NOT written into `config.yaml`'s `extensions:` block** (single source of truth; resolves the C3 double-registration). Consequently, per-session MCP tools are governed by `mode` + runtime HITL, not by `available_tools` (which applies only to config.yaml-declared extensions — §7).

### 5.2 `is_default` selection (Opus S5)

`poco_configs` has a unique index only on `name`, so zero or multiple `is_default=true` rows are possible.
- **Global render:** if exactly one default → use it. If multiple → oldest `created` wins **and log a warning**. If none → **skip the config.yaml render entirely** and let Goose boot on compose-env defaults (§6.4); log at info.
- **Per-chat fallback:** `resolveProfile` uses `chats.poco_config` if set; else the resolved default (same tie-break); if still none, a built-in minimal profile (workspace cwd, empty mcpServers, mode `approve`).

## 6. Render pipeline (replaces the OpenCode renders)

### 6.1 New pure package `internal/gooseconfig/` (no I/O — golden-testable)
- `config.go` — the default `poco_config` (+ `harness_model`, `system_prompt`) → a `config.yaml` document: `GOOSE_PROVIDER`, `GOOSE_MODEL`, `GOOSE_MODE`, and an `extensions:` block **for globally-declared/builtin extensions only** (not the per-chat MCP servers). A global `instructions`/system-prompt key is emitted **only if §13.5 confirms the pinned build supports one** — otherwise omitted (do not invent a key). Marshals to YAML.
- `keys.go` — `provider_keys.env_vars` (JSON, all rows) merged → `KEY=VALUE` lines. **This file is the only place secrets live; never returned to any client.**
- `permissions.go` — `tool_permissions` (active) → per-extension `available_tools` allowlist + a mode nudge, per §7. Returns the merged config plus the list of dropped/degraded rules for logging.

### 6.2 New hook `internal/hooks/goose_config.go`
Watches `poco_configs`, `provider_keys`, `tool_permissions`, `harness_models`, `prompts`; on change renders `config.yaml` + `keys.env` to the shared config volume, then `renderAndRestart(prefix, render, GooseContainer, e)`. Reuses `renderAndRestart`/`restartContainer` unchanged (`helpers.go`, `docker.go`). Introduces `GooseContainer = "pocketcoder-goose"`; removes `PocoContainer`.

### 6.3 Retired code
- `hooks/llm.go` `/workspace/.opencode/llm.env` render → replaced by `gooseconfig.keys`.
- `hooks/tool_permissions.go` `opencode.json` render → replaced by `gooseconfig.config`/`permissions`.
- `agents/bundler.go` `GetAgentBundle`/`UpdateAgentConfig` and the `agents.go` hook that calls them (confirmed dead — `agents.go`, `bundler.go`) → removed; `poco_configs.config` no longer written (and dropped, §5).
- `PocoContainer = "pocketcoder-interface"` and both restarts targeting it.

### 6.4 File ownership & permissions (Opus C1 — load-bearing)
PocketBase runs as **root** (`services/pocketbase/Dockerfile` — no `USER`); Goose runs as **non-root** (`services/goose/Dockerfile`, `USER goose`). A root-owned `0600` file is unreadable by Goose and would crash the container (`entrypoint.sh` `set -eu` + provider check). Therefore, after writing, PocketBase (root) **`chown`s both files to the Goose runtime uid** and sets:
- `keys.env` → `0600` (secret), owned by goose uid.
- `config.yaml` → `0640`, owned by goose uid.

The Goose uid must be confirmed (§13.4). This is the single change most likely to make a dev-correct design fail on the box.

### 6.5 Cold-start / initial render (Opus S2)
The retired hooks rendered once on `OnServe` **without** a restart. `goose_config.go` keeps that: an `OnServe` initial render writes `config.yaml`/`keys.env` (no restart). On cold boot compose starts `goose` and `pocketbase` concurrently; Goose reads config at its own startup. If PocketBase hasn't rendered yet, **Goose boots on the compose-env defaults** (`GOOSE_PROVIDER`/`GOOSE_MODEL`/`ANTHROPIC_API_KEY`), which remain valid bootstrap values; the first subsequent config edit triggers a render+restart onto the app-managed config. This is acceptable and explicit — compose-env is the floor, PocketBase config is the override.

## 7. Tool-policy mapping (rich rows → Goose, lossy but documented)

Goose has no per-tool allow/ask/deny; it has a per-extension `available_tools` allowlist (non-empty = only those tools) plus the coarse `mode`. `available_tools` applies **only to extensions declared in `config.yaml`** (builtins/global), not to per-session MCP servers (§5.1).

| `tool_permissions.action` | Goose effect |
| --- | --- |
| `allow(tool)` | add `tool` to that extension's `available_tools` |
| `deny(tool)` | ensure `tool` is excluded from `available_tools` |
| `ask(tool)` | **no per-tool Goose equivalent** — dropped from the allowlist and **logged**; governance falls to `mode` |

Rules & documented degradations (all **logged**, never silent):
- An extension with any `allow`/`deny` rows renders `available_tools = allow-set − deny-set`; none → omit (Goose default = all tools).
- **`pattern` is discarded** — Goose's allowlist is tool-name-only (`tool_permissions.pattern` is Required in schema but unrepresentable). Each dropped pattern is logged.
- **Same-tool `allow`+`deny` conflict** → deny wins (tool excluded); logged, because the allowed pattern silently vanishes otherwise.
- **`ask(tool)`** → dropped + logged; runtime HITL over ACP still governs approvals.

## 8. Coordinator changes

**Injection boundary (important):** the `Coordinator` holds **no `core.App`** — it is PocketBase-agnostic, and all DB access is injected from the API layer via closures (`ResolveSession`, `OnSessionCreated`; see `internal/api/agent.go`). Profile resolution follows the same seam. So `SessionProfile` and the appliers live in the coordinator (pure, acpsdk types only), but **`resolveProfile` reads PocketBase and therefore lives at the API layer** and is injected — it is *not* a coordinator function with a `core.App` parameter.

New `internal/agent/coordinator/profile.go` (no `core.App` import):
- `type SessionProfile struct { Model, Provider, Instructions, Cwd string; AdditionalDirectories []string; McpServers []acpsdk.McpServer; Mode acpsdk.SessionModeId }` (Opus N3 — fully specified; no `toolPolicy`, per S7).
- `type ProfileFunc func(context.Context) (SessionProfile, error)` — the injected resolver, mirroring `ResolveSession`.
- `ProfileApplier` interface + `GlobalConfigApplier` (impl) + `PerSessionApplier` (stub) + `selectApplier(initResp *acpsdk.InitializeResponse) ProfileApplier` (§4).

New `internal/api/profile.go` (has `core.App`):
- `func buildSessionProfile(app core.App, chatID string) (coordinator.SessionProfile, error)` — reads `chats.poco_config` (or default per §5.2), applies `harness_model_override` into `Model` (inert per-chat today, §4.1), performs the two-hop `harness_model → harness_models.model → models.provider` expand, `system_prompt → prompts.body`, parses `acp_mcp_servers` (§5.1) and `workspace_folders` (§5 / S4), resolves `mode`. The `session/prompt` and `stream`(cold-replay) handlers build it and pass it in.

Coordinator wiring:
- `StartPrompt` (and the cold-replay entry `StreamColdReplay`) gain a `ProfileFunc` parameter, injected by the API handlers exactly as `ResolveSession` is today.
- `initSession` (function, not line): capture the `Initialize` response (currently discarded) to feed `selectApplier` (Opus S8); build `NewSession`/`LoadSession` requests from the resolved `profile.Cwd`/`AdditionalDirectories`/`McpServers` in **both** branches (Opus C2), replacing the hardcoded empty `McpServers`; after the sessionID exists, `applier.Apply(ctx, conn, sessionID, profile)` replaces the hardcoded `SetSessionMode("approve")`.
- `SeedSession` and orphan compensation stay exactly as the bridge plan built them.

## 9. Infra (compose + entrypoint)

- Shared volume `goose_config` mounted into `pocketbase` (writable) and `goose` (read). Goose's config path is a **verify item** (§13.1): `GOOSE_PATH_ROOT=/goose` is already set (`docker-compose.yml`) and may itself be the config root, in which case the `XDG_CONFIG_HOME` approach is wrong. Resolve before wiring the mount path.
- `services/goose/entrypoint.sh`: source `keys.env` **before** the provider/`ANTHROPIC_API_KEY` validation block (Opus S3), guarded so `set -e` cannot abort on a missing/unreadable file:
  ```sh
  if [ -r /goose-config/keys.env ]; then set -a; . /goose-config/keys.env; set +a; fi
  # ... existing GOOSE_SERVER__SECRET_KEY + provider/ANTHROPIC_API_KEY validation ...
  exec /usr/local/bin/goose serve --host 0.0.0.0 --port 3000
  ```
- Docker-proxy restart retargeted to `pocketcoder-goose` (name change only; already reachable via the write proxy).

## 10. Restart-vs-run coherence (Opus S1 — documented decision)

`renderAndRestart` restarts Goose out-of-band from any run. Runs are detached goroutines holding a live WS `conn` mid-`Prompt`. An admin editing a `poco_config`/key **mid-run restarts Goose, drops the WS, and the in-flight turn fails** (surfaced as `goose_unavailable` through the bridge). Goose persists session history, so the next prompt reloads via `session/load` and state is intact — only the active turn is lost.

**Decision: accept.** Config edits are rare admin operations; the blast radius is one in-flight turn, recoverable by resending. A future debounce/drain is possible but out of scope. This is documented so it is not discovered at runtime.

## 11. Security invariants (unchanged, restated)

1. `GOOSE_SERVER__SECRET_KEY` and provider API keys **never** appear in any response to Flutter/browser. Keys live only in the rendered `keys.env` (goose-uid-owned, `0600`) on the shared volume, sourced by the entrypoint; nothing writes keys into `config.yaml` or any response.
2. Goose has **no** network path to PocketBase's DB and no PocketBase token — this spec adds only a shared **file** volume, not a network channel.
3. Render permissions/ownership per §6.4.

## 12. Testing (TDD)

- **Renderers** (`internal/gooseconfig/*_test.go`): golden-file tests — fixtures → expected `config.yaml`/`keys.env`; explicit lossy-map cases (§7: `deny`→exclude, `ask`→drop+log, `pattern`→drop+log, allow∩deny→deny-wins+log, no-rows→omit allowlist), multi-`provider_keys` merge, stdio-only MCP filtering (§5.1), `is_default` zero/one/multiple (§5.2).
- **Coordinator** (`coordinator/profile_test.go`): `resolveProfile` two-hop + fallback; fake `ProfileApplier` + fake `acp.Conn` assert `profile.McpServers`/`Cwd`/`AdditionalDirectories` reach the `NewSession`/`LoadSession` request and `Mode` reaches `Apply`; `selectApplier` returns `GlobalConfigApplier` under today's advertised capabilities.
- **Hook** (`hooks/goose_config_test.go`): a `poco_configs` update renders to the configured path (with correct owner/mode, §6.4) and triggers a restart call (restart faked/observed); `OnServe` initial render does **not** restart (§6.5).

## 13. Verify against the pinned Goose version (do NOT assume)

1. **(Elevated — load-bearing)** Goose config-file location. `GOOSE_PATH_ROOT=/goose` is already set; confirm whether config lives at `$GOOSE_PATH_ROOT/config.yaml`, `~/.config/goose/config.yaml`, or honors `XDG_CONFIG_HOME`, and mount the shared volume accordingly. Interacts with §6.4.
2. Secret delivery with `GOOSE_DISABLE_KEYRING=1` — confirm keys are read from **env** (sourced `keys.env`) and not a keyring/secrets file; if Goose expects a secrets file, render that instead.
3. **(Elevated — gates the schema enum)** Which session modes / config options the ACP server advertises in our build. The `poco_configs.mode` enum (§5) is provisional until confirmed; only `approve` is known-good.
4. **(New — Opus C1)** The Goose runtime **uid/gid** in the pinned image, so PocketBase's `chown` targets the right owner (§6.4).
5. **(New)** Whether `config.yaml` (or an env var) supports a **global system prompt / instructions** in the pinned build. If yes, the renderer emits it; if no, the system prompt is inert (documented in §4.1) and the renderer omits it — do **not** invent a config key. `system_prompt`/`Instructions` stays on the record + `SessionProfile` regardless (it becomes live per-chat when recipe-over-ACP lands).

## 14. Module structure summary

```
internal/gooseconfig/            NEW — pure renderers (config.yaml, keys.env, permissions), golden-tested
  config.go  keys.go  permissions.go
internal/hooks/goose_config.go   NEW — watch config collections → render (owner/mode) → renderAndRestart(GooseContainer); OnServe initial render (no restart)
internal/hooks/helpers.go        MODIFY — GooseContainer const; remove PocoContainer
internal/hooks/llm.go            REMOVE OpenCode render (superseded by gooseconfig.keys)
internal/hooks/tool_permissions.go REMOVE opencode.json render (superseded by gooseconfig.config/permissions)
internal/hooks/agents.go         REMOVE bundle hook
internal/agents/bundler.go       REMOVE GetAgentBundle/UpdateAgentConfig
internal/agent/coordinator/profile.go  NEW — SessionProfile, ProfileFunc, ProfileApplier, GlobalConfigApplier, PerSessionApplier(stub), selectApplier (no core.App)
internal/api/profile.go                NEW — buildSessionProfile(app, chatID) (has core.App); injected into StartPrompt/StreamColdReplay
internal/agent/coordinator/run.go      MODIFY StartPrompt/StreamColdReplay take ProfileFunc; initSession — capture initResp; build NewSession/LoadSession from profile; Apply(mode) post-create
internal/api/agent.go                  MODIFY prompt + stream handlers build & inject the profile
migrations/                      NEW — add poco_configs.mode enum (after §13.3); drop poco_configs.config
services/goose/entrypoint.sh     MODIFY — source /goose-config/keys.env before provider validation
docker-compose.yml               MODIFY — goose_config shared volume; config path per §13.1
```
