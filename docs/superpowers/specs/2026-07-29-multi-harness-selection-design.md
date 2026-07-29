# Multi-Harness Selection — Design Spec

**Date:** 2026-07-29
**Status:** DESIGN — pending planning
**Grounded against (code, not docs):** `server/pocketbase/internal/agent/coordinator/{run.go,profile.go}`, `server/pocketbase/internal/api/profile.go`, `server/pocketbase/internal/hooks/goose_config.go`, `server/pocketbase/pb_migrations/{schema.json,1756000100_seed.go}`, `docker-compose.yml` (goose + docker-socket-proxy-write services), `client/packages/pocketcoder_flutter/lib/{presentation/chat/chat_list_screen.dart,application/chat/chat_list_cubit.dart,infrastructure/chat/chat_list_repository.dart,domain/chat/i_chat_list_repository.dart}`.

---

## 1. Why this exists

The user wants to be able to run different agent harnesses — not just different models within one harness, but genuinely different harness binaries (goose fronting a provider today; a bare ACP agent with no goose in front, tomorrow) — and pick cwd + harness + model explicitly per chat, the same way a terminal user picks a working directory and a CLI before starting a session. Nothing in the codebase currently supports more than one harness *type*; the goal is to make that real, without over-building automatic isolation machinery the user explicitly does not want yet.

## 2. Current state, verified directly from code (not from prior specs)

- **`docker-compose.yml`**: exactly one `goose` service. `Coordinator.New()` (`run.go:110-113`) hard-requires a single `GooseURL`/`GooseSecret`/`Workspace`; `config.Dial` always dials that one fixed endpoint. There is no multi-instance or multi-harness-type capability anywhere in the coordinator.
- **Per-chat model/provider switching within goose already works.** `initSession` (`run.go:772-822`) calls `applier.Apply(...)` on every session; `selectApplier` (`profile.go:145-147`) always returns `PerSessionApplier`, which issues real `session/set_config_option` calls for `provider` and `model` (`profile.go:103-137`), confirmed against goose v1.43.0. `buildSessionProfile` (`api/profile.go:43-118`) already resolves `chats.harness_model_override` (falling back to `poco_config.harness_model`) into this live path. **This needs no new design work.**
- **No per-chat cwd.** `profile.Cwd` comes only from `poco_configs.workspace_folders` (`api/profile.go:93-99`), which is shared by every chat using that `poco_config`. `docker-compose.yml` mounts one `goose_workspace` volume into both `pocketbase` and `goose`. There is no chat-level cwd field and no automatic isolation between chats sharing a `poco_config`.
- **`harnesses` is a static, currently-empty catalog** (`pc_harnesses`: `name`, `cli_id` unique, `version`, `description`, `acp_transport` ∈ {websocket, stdio, http|). No seed rows exist (`1756000100_seed.go` has none). It describes harness *types* but has no field describing how to actually run one, and nothing in the code provisions a container from it.
- **`docker-socket-proxy-write`** (`docker-compose.yml:203-224`) already grants `CONTAINERS=1`, `POST=1`, `EVENTS=1`. This is enough for container create/start/stop/restart and for subscribing to the Docker event stream, **without any proxy config change** — `IMAGES=0`/`NETWORKS=0`/`VOLUMES=0` block operations on those objects (pulling images, creating networks/volumes) but not attaching an *already-existing* named volume or joining an *already-existing* network to a newly created container, since that's part of the container-create call.
- **No client-facing selection UI.** `ChatListCubit.createAndOpen()` → `ChatDao.save({title, user})` only — no `poco_config`, `harness_model_override`, or workspace field is ever set from the client, even though the `Chat` model already carries `pocoConfig`/`harnessModelOverride` fields unused by the create path.

## 3. Goal and explicit non-goals

**Goal:** a user creating a new chat picks cwd + harness + model, and the system runs whichever harness container that implies, routing that chat's ACP session to it.

**Explicit non-goals (YAGNI, confirmed):**
- No automatic per-chat worktree or workspace isolation. cwd is the user's own explicit choice, same as `cd`-ing before running a terminal CLI. If two chats collide on one directory, that's the user's call, not a system guarantee. (A later PocketBase-side "create a worktree for me" convenience is plausible future work, explicitly deferred.)
- No live agent-to-agent protocol between harnesses. If harnesses need to share output, that's the shared workspace volume, nothing more.
- No arbitrary bring-your-own Docker image in v1. A harness is provisioned from a catalog entry (`harnesses` row) whose `container_image`/`launch_template` is trusted, pre-built content — not a user-supplied image reference. (Still meaningfully extensible: adding a new `harnesses` row is the extension point, and since every deployment is the user's own VPS — not shared infra — this is a much lower-stakes trust boundary than a multi-tenant SaaS.)

## 4. Schema changes

### 4.1 `chats` — add `workspace_override`

New field `workspace_override` (json array, nullable), same shape as `poco_configs.workspace_folders` (first element is `cwd`, remainder is `additionalDirectories`). Resolution mirrors the existing `harness_model_override` pattern exactly: chat value wins if set, else fall back to the `poco_config`'s `workspace_folders`.

### 4.2 `harnesses` — add provisioning fields

- `container_image` (text, required) — the image PocketBase creates a container from.
- `launch_template` (json, required) — command/env shape PocketBase renders when creating an instance (e.g. `{"cmd": [...], "env_template": {...}, "port": 3000}`).
- `supports_live_config` (bool, default `true`) — whether this harness type can switch provider/model per-session at runtime (goose: `true`, confirmed above). A harness where this is `false` needs one running instance **per distinct `harness_model`**, not one shared instance — see §4.3.

### 4.3 New collection `harness_instances` — runtime container tracking

Tracks containers PocketBase has actually provisioned, distinct from the static `harnesses` catalog. A row exists once any chat has selected that harness (or harness+model combo), whether or not the container is currently up.

| Field | Type | Notes |
|---|---|---|
| `id` | text (PB-owned PK) | |
| `harness` | relation → `harnesses` | required |
| `harness_model` | relation → `harness_models`, nullable | required only when `harness.supports_live_config = false` (a fixed-at-launch model needs its own instance); left empty when the harness supports live per-session switching, since one instance then serves every model choice under that harness |
| `container_name` | text, unique | the actual Docker container name |
| `acp_endpoint` | text | e.g. `ws://<container_name>:3000/acp` |
| `status` | select: `pending`\|`running`\|`stopped`\|`error` | updated by the event watcher (§5.2) |

**Invariant enforced in application code, not solely by a DB constraint** (SQLite unique indexes treat `NULL` as distinct, so a naive unique index on `(harness, harness_model)` would not stop multiple null-`harness_model` rows): before creating a new `harness_instances` row for a `supports_live_config = true` harness, check no row already exists for that harness and reuse it instead.

## 5. Runtime behavior

### 5.1 Chat → instance resolution (replaces the single hardcoded `GooseURL`)

`buildSessionProfile` gains a resolution step: `chat.harness_model_override` (or `poco_config.harness_model`) → `harness_models.harness` → look up the `harness_instances` row for that harness (and, if `supports_live_config = false`, that specific `harness_model` too) → if no row exists, provision one from `harnesses.container_image`/`launch_template` via `docker-socket-proxy-write`, attaching the existing `goose_workspace` volume and `pocketcoder-agent` network → dial `acp_endpoint`. `Coordinator.Config.GooseURL` becomes a per-chat resolved value instead of a fixed field; the default/no-selection case still resolves to today's single goose instance so existing deployments are unaffected.

### 5.2 Reactive status tracking

A small watcher subscribes to the Docker event stream through `docker-socket-proxy-write` (`EVENTS=1`, already enabled) and updates the matching `harness_instances.status` row on container start/die/health-change, so PocketBase's view of "is this harness actually up" doesn't drift from reality without polling.

### 5.3 Constrained combinations

`harness_models` already constrains which models are valid for which harness (join table, unique on `(harness, model)`) — the client only ever offers models that have a row there for the selected harness. A model additionally requires the current user to have a `provider_keys` row for that model's `provider`; the client should filter/flag accordingly (existing `provider_keys` unique index on `(user, provider)` already supports this check).

## 6. Client-facing surface

`ChatDao.save`/`createChat` gains optional `harnessModel` and `workspaceOverride` parameters, threaded from a new chat-creation step in `chat_list_cubit.dart`/`chat_list_screen.dart` that lets the user pick cwd + harness + model before the chat is created (today it's a bare title-only insert). This is the actual point where "the user chooses, like terminal Claude Code" becomes real — everything upstream in this spec exists to make that choice mean something.

## 7. Testing

- **Schema/migration**: golden-file or fixture test that a `chats.workspace_override` value overrides `poco_config.workspace_folders` in `buildSessionProfile`, mirroring the existing `harness_model_override` test coverage.
- **Instance resolution**: fake `docker-socket-proxy-write` client — assert a first-time chat→harness selection provisions exactly one instance (reused on a second chat with `supports_live_config=true`, and a second distinct instance for a `supports_live_config=false` harness with a different model).
- **Event watcher**: fake Docker event stream — assert a `die` event flips the matching row to `stopped`, a `start`/healthy event flips it to `running`.
- **Client**: existing chat-creation tests extended to cover the new optional params defaulting to today's behavior when omitted (backward-compatible bare-title creation still works).

## 8. Open questions / risks carried forward

- **Resource footprint**: each non-goose harness instance is another always-on daemon on what may be a modest VPS. No lazy-stop-when-idle mechanism is designed here — first real harness beyond goose should validate whether this matters in practice before building one.
- **stdio-transport harnesses**: `harnesses.acp_transport = stdio` cannot be reached across a Docker network as a separate container (stdio is a local-subprocess transport only). A `stdio` harness type would need to run as a child process inside an existing container (the way goose spawns `GOOSE_PROVIDER=claude-acp` today) rather than as its own `harness_instances` row — this spec covers `websocket`/`http` transport harnesses as independent containers; `stdio` harnesses are out of scope until a concrete case arises.
- **Per-chat worktree convenience**: explicitly deferred (§3). If stomping between chats sharing a `workspace_override` value becomes a real complaint, a future PocketBase-side "create me a worktree" action is the natural next step, not automatic isolation.
