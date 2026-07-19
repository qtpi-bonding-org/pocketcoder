# Agent-Definition Revamp — DRAFT Spec

**Date:** 2026-07-18
**Status:** DRAFT — capture only. Needs a full brainstorming pass before it earns an implementation plan. Do NOT execute from this document.
**Depends on:** Legacy Runtime Prune landing first (which leaves this subsystem intact-but-vestigial by choice). This is the largest and least-defined of the three follow-ups.

## Why this exists

The agent-definition subsystem was built for **OpenCode**: editing config records renders `/workspace/.opencode/` files (`llm.env`, `opencode.json`) and restarts the removed `pocketcoder-interface` container. Post-prune, those renders still fire but land in a volume nothing reads, and the container restart 404s and no-ops. Meanwhile **Goose (c2)** is configured entirely by **process-global env** (`GOOSE_PROVIDER`/`GOOSE_MODEL`/`ANTHROPIC_API_KEY`) with **no per-agent recipe mechanism** wired up. This revamp redesigns agent definition around Goose (recipes / per-session config) instead of OpenCode files.

## Current state (grounded)

**Three hooks** (registered `main.go` lines 47/56/59):

- **`hooks/agents.go`** — no file render, no restart. Keeps `poco_configs.config` (a YAML-frontmatter + prompt bundle from `agents/bundler.go::GetAgentBundle`) in sync on `poco_configs` create/update requests; re-bundles when a linked `prompts` or `harness_models` row changes.
- **`hooks/llm.go`** — renders `/workspace/.opencode/llm.env` (+ shared `/llm_keys/llm.env`) from all `provider_keys.env_vars` JSON; on `provider_keys` CRUD calls `renderAndRestart(..., PocoContainer)`. Also renders on `OnServe`.
- **`hooks/tool_permissions.go`** — patches `/workspace/.opencode/opencode.json`: global `permission` block + per-agent `agent[name] = {model, prompt, permission}` from `tool_permissions` (active=true), `harness_models.harness_model_id`, `prompts.body`. Restarts `PocoContainer` on `tool_permissions` CRUD and `poco_configs` update.

**Restart mechanism** (`hooks/helpers.go` + `hooks/docker.go`): `PocoContainer = "pocketcoder-interface"` (helpers.go:29); `renderAndRestart` → `restartContainer(container, 30s)` (helpers.go:40) → POST to `docker-socket-proxy-write:2375` `/containers/{name}/restart` (docker.go:59). **404 is logged and skipped** (docker.go:66–69) — so today every restart no-ops because the container is gone.

**Collections** (two generations):
- *Legacy* (`1740000100_consolidated_schema.go`): `ai_prompts`, `ai_models`, `ai_agents` (name/desc/mode/temperature/is_init, prompt+model relations), `sandbox_agents`, legacy `tool_permissions` (per `ai_agents`). **None touched by the current hooks.**
- *Newer ACP* (`1748000100_acp_schema.go`): `harnesses` (cli_id/version/acp_transport), `models`, `harness_models` (harness×model + `harness_model_id` string), `provider_keys` (per-user, `env_vars` JSON — source of llm.env), `prompts`, `skills` (defined, unused), `poco_configs` (**primary agent def**: `harness_model`, `system_prompt`, `workspace_folders`, `acp_mcp_servers`, `is_default`, `config`). `tool_permissions` gains `poco_config`/`sandbox_config` relations here.
- **Actually read by hooks:** `provider_keys`, `tool_permissions`, `poco_configs`, `harness_models`, `prompts`. **Written back:** only `poco_configs.config`.

**What OpenCode config encodes (what a Goose equivalent must replace):** (a) per-agent model (`harness_model_id`), (b) per-agent system prompt (`prompts.body`), (c) global + per-agent tool-permission policy (allow/ask/deny), (d) provider credential delivery (`llm.env`).

**Goose config mechanism today:** `services/goose/` has only `Dockerfile` + `entrypoint.sh` — **no recipe files**. Config is env-only: `GOOSE_PROVIDER` (only `anthropic` accepted), `GOOSE_MODEL`, `ANTHROPIC_API_KEY`, `GOOSE_SERVER__SECRET_KEY`, `GOOSE_PATH_ROOT=/goose`, `GOOSE_DISABLE_KEYRING=1`. `goose serve` runs one process-global config. ACP `session/new` can pass MCP servers; `session/set_mode` picks a pre-defined mode. `goose_sessions` (chat/user/goose_session_id/goose_version/provider) is the only c1-side Goose mapping.

## What we know we want (loose)

- Agent definition (model, system prompt, tools/permissions, MCP servers) expressed as something **Goose consumes** — Goose **recipes** and/or ACP `session/new` params — not OpenCode files.
- Kill the `/workspace/.opencode/` renders and the `pocketcoder-interface` restart entirely.
- Decide the fate of the two collection generations — collapse legacy `ai_*` into the `poco_configs`/`harness_models` world, or start clean.
- Provider credentials delivered to Goose the Goose-native way (env / keyring / recipe), replacing `llm.env`.

## Open questions (resolve in brainstorming — many)

1. **Recipe vs per-session:** does a "poco_config" become a **Goose recipe file** (rendered where? mounted how? read by `goose serve` or per `session/new`?), or is it applied dynamically via ACP `session/new`/`session/set_mode` params per turn? Goose currently runs **one global config** — is multi-agent even a near-term goal, or is it one configurable agent?
2. **Per-agent model:** Goose model is process-global env today. Can a recipe or `session/new` override model per session, or does per-agent model require a Goose feature we don't have? (Verify against the pinned v1.43.0's recipe capabilities.)
3. **Tool permissions:** how do OpenCode's allow/ask/deny map to Goose? Goose has `session/set_mode` (approve/etc.) + MCP server allow-listing — is that the whole surface, or is finer-grained per-tool policy lost/deferred? Ties to the Flutter approvals flow.
4. **Provider keys:** does Goose read credentials from env only, or can a recipe carry them? How do per-user `provider_keys` reach a shared `goose serve` — env at container start (one provider) vs per-session injection (multi-tenant)?
5. **Collection cleanup:** which of `ai_prompts`/`ai_models`/`ai_agents`/`sandbox_agents`/`harnesses`/`models`/`skills` survive? What's the minimal schema for Goose-based definition? (Candidate forward-only migration to drop the dead ones.)
6. **Where does rendering/restart go:** if recipes are files, what writes them and does Goose need a restart or a session-scoped reload? If ACP-dynamic, delete the render/restart machinery outright (docker.go restart path, PocoContainer).
7. **MCP servers:** `poco_configs.acp_mcp_servers` + the `mcp_servers` collection + c3 gateway — how does agent def wire MCP into `session/new`? (Overlaps c3 enablement.)
8. **Scope of v1:** one well-configured default agent, or true multi-agent selection? Strongly recommend scoping v1 to the smallest useful thing and deferring multi-agent.

## Non-goals

- c3 / Cognee enablement (except where MCP wiring forces a decision — flag, don't build).
- The Flutter config UI (separate; consumes whatever schema this settles on).
- Keeping OpenCode compatibility.

## Next step

This is under-specified and broad — a full `superpowers:brainstorming` pass is essential, likely starting by pinning down Goose's actual recipe/session capabilities on the pinned image before any design. Then `writing-plans`. This draft is context, not a plan.
