# Multi-Harness Selection — Design Spec

**Date:** 2026-07-29
**Status:** DESIGN — revised after Opus review (round 1); pending round 2
**Grounded against (code, not docs):** `server/pocketbase/internal/agent/coordinator/{run.go,profile.go,admin.go}`, `server/pocketbase/internal/api/profile.go`, `server/pocketbase/internal/hooks/{goose_config.go,mcp_gateway.go,schedule_importer.go,cognee_extension.go}`, `server/pocketbase/internal/api/{skills.go,schedules.go}`, `server/pocketbase/pb_migrations/{schema.json,1756000100_seed.go}`, `docker-compose.yml` (goose + docker-socket-proxy-write services), `client/packages/pocketcoder_flutter/lib/{presentation/chat/chat_list_screen.dart,application/chat/chat_list_cubit.dart,infrastructure/chat/chat_list_repository.dart,domain/chat/i_chat_list_repository.dart}`, PocketBase `core/field_relation.go`/`core/field_json.go` (v0.36.1, for how relations vs. JSON fields actually store "unset").

---

## 1. Why this exists

The user wants to be able to run different agent harnesses — not just different models within one harness, but genuinely different harness binaries (goose fronting a provider today; a bare stdio ACP agent like `claude-agent-acp` with no goose in front, as the concrete next one) — and pick cwd + harness + model explicitly per chat, the same way a terminal user picks a working directory and a CLI before starting a session. Nothing in the codebase currently supports more than one harness *type*; the goal is to make that real, without over-building automatic isolation machinery the user explicitly does not want yet.

## 2. Current state, verified directly from code (not from prior specs)

- **`docker-compose.yml`**: exactly one `goose` service. `Coordinator.New()` (`run.go:110-113`) hard-requires a single `GooseURL`/`GooseSecret`/`Workspace`. The default `DialFunc` closure built in `New` (`run.go:114-118`) captures these at construction — but `Dial` itself is an injectable field on `Config` (already used by tests), not a hardcoded call, which matters for §5.1's fix.
- **Per-chat model/provider switching within goose already works.** `initSession` (`run.go:772-822`) calls `applier.Apply(...)` on every session. `selectApplier` (`profile.go:145-147`) **unconditionally** returns `PerSessionApplier`, ignoring the `*acpsdk.InitializeResponse` argument it's given — today that's harmless because there is only ever one harness (Goose) to select for. `PerSessionApplier.Apply` (`profile.go:103-137`) issues standard ACP `session/set_config_option` for `provider`/`model`, confirmed against goose v1.43.0, **plus** a Goose-private custom method `_goose/unstable/session/system-prompt/set` (`profile.go:130`) for instructions. `buildSessionProfile` (`api/profile.go:43-118`) resolves `chats.harness_model_override` (falling back to `poco_config.harness_model`) into this live path. **The live-switching mechanism itself needs no new design work — but `selectApplier`'s unconditional choice becomes a live bug the moment a second, non-Goose harness exists** (see §6.4).
- **`buildSessionProfile` has an early-return bug that matters a lot for this design.** `api/profile.go:61-66`: when `poco == nil` (no `chats.poco_config` set *and* no `is_default` `poco_config` exists — the actual state of a fresh deployment, since `1756000100_seed.go` seeds none of `harnesses`/`models`/`harness_models`/`poco_configs`/`provider_keys`), the function returns immediately, **before** reading `harness_model_override` (line 70) or `workspace_folders` (lines 93-99). So on a fresh box, chat-level overrides are silently ignored. This must be fixed as part of this work, not treated as pre-existing and out of scope, because harness resolution (§5.1) depends on exactly the fields this bug skips.
- **No per-chat cwd.** `profile.Cwd` comes only from `poco_configs.workspace_folders`, shared by every chat using that `poco_config`. `docker-compose.yml` mounts one `goose_workspace` volume into both `pocketbase` and `goose`, declared with no `name:`/`external: true` — the real Docker object is `<compose-project>_goose_workspace`, not a name known in advance (see §5.1.2).
- **`harnesses` is a static, currently-empty catalog** (`pc_harnesses`: `name`, `cli_id` unique, `version`, `description`, `acp_transport` ∈ `{websocket, stdio, http}`). No seed rows exist. It describes harness *types* but has no field describing how to actually run one, and nothing in the code provisions a container from it.
- **`docker-socket-proxy-write`** (`docker-compose.yml:203-227`) grants `CONTAINERS=1`, `POST=1`, `EVENTS=1`, and explicitly `IMAGES=0`/`NETWORKS=0`/`VOLUMES=0`. `CONTAINERS`+`POST` is enough for container create/start/stop, and covers container **attach** too (`POST /containers/{id}/attach`) — `EXEC=0` blocks `docker exec`, not attach, which matters for stdio harnesses (§5.4). `EVENTS=1` allows subscribing to the Docker event stream. `IMAGES=0` means **PocketBase cannot pull an image it doesn't already have locally** — creating a container from a missing image fails outright, with no fallback (§5.1.1, this is a real gap in the original draft of this spec).
- **`AdminConn`** (`admin.go:76-88`) dials the single configured Goose with no chat/harness context at all, and is the transport for: `hooks/goose_config.go` (live tool-permission delivery), `hooks/mcp_gateway.go`, `hooks/schedule_importer.go`, `hooks/cognee_extension.go`, `api/skills.go` (×2), `api/schedules.go` (×2) — nine call sites total, several of which use Goose-private custom methods. None of this fans out to multiple harnesses in this spec; see §5.5 for what stays Goose-only.
- **`goose_sessions` has `UNIQUE(chat)` and `UNIQUE(goose_session_id)`.** A chat maps to exactly one session id, globally, minted by whichever agent process created it and only loadable there. This is the load-bearing fact that shapes §5.6 below — the original draft of this spec missed it entirely.
- **No client-facing selection UI.** `ChatListCubit.createAndOpen()` → `ChatDao.save({title, user})` only — no `poco_config`, `harness_model_override`, or workspace field is ever set from the client, even though the `Chat` model already carries `pocoConfig`/`harnessModelOverride` fields unused by the create path.

## 3. Goal and explicit non-goals

**Goal:** a user creating a new chat picks cwd + harness + model, and the system runs whichever harness container that implies, routing that chat's ACP session to it.

**Explicit non-goals (YAGNI, confirmed):**
- No automatic per-chat worktree or workspace isolation. cwd is the user's own explicit choice, same as `cd`-ing before running a terminal CLI. If two chats collide on one directory, that's the user's call, not a system guarantee. (A later PocketBase-side "create a worktree for me" convenience is plausible future work, explicitly deferred.)
- No live agent-to-agent protocol between harnesses. If harnesses need to share output, that's the shared workspace volume, nothing more.
- No arbitrary bring-your-own Docker image reference from an end user. A harness is provisioned from a catalog entry (`harnesses` row), which only a superuser can create (`createRule: null` today, unchanged) — so "extensibility" means "an admin adds a catalog row," not "any user supplies an image string." Given every deployment is the user's own VPS, not shared infra, this is a much lower-stakes trust boundary than a multi-tenant SaaS, which is why §5.1.1 is comfortable proposing `IMAGES=1`.
- **No longer a non-goal: stdio-transport harnesses.** The original draft excluded these, which contradicted §1's own motivating example (`claude-agent-acp` is stdio). §5.4 covers this properly instead of carving it out.

## 4. Schema changes

### 4.1 `chats` — add `workspace_override` and `harness`

- **`workspace_override`** (json, nullable — PocketBase's JSON columns are genuine `NULL`-capable, unlike relations, so "unset" and "explicitly empty" are distinguishable). Same element shape as `poco_configs.workspace_folders`, but see §5.7 for exactly how it composes with the poco's value — it does **not** simply replace the whole array.
- **`harness`** (relation → `harnesses`, `maxSelect: 1`, not required). Needed because harness selection cannot only be derived from model choice (§5.6.1) — a harness with no `harness_models` rows (e.g. one with its own baked-in subscription auth and no PocketCoder-visible model list) would otherwise be unselectable.
- New non-unique index `CREATE INDEX idx_chats_user_archived ON chats (user, archived)` — `chats` has zero indexes today, and this design is adding lookups on the collection anyway (client-side harness/model filtering), so an additive index is cheap to include now.

### 4.2 `harnesses` — add provisioning fields, and split the overloaded capability flag

- `container_image` (text, required) — the image PocketBase creates a container from.
- `launch_template` (json, required) — command/env shape PocketBase renders when creating an instance. Must express: entrypoint `cmd`, `env_template` (may reference `{{provider_key_env}}`-style placeholders resolved from `provider_keys` at create time — see §5.5 for why this is create-time, not live, for non-Goose harnesses), the ACP port (for `websocket`/`http` transport), and which of `websocket|stdio|http` it uses (redundant with `acp_transport` today — keep `acp_transport` as the source of truth, `launch_template` only carries the port/command).
- `supports_live_config` (bool, default `true`) — whether this harness type can switch provider/model per session at runtime without restarting (Goose: `true`, confirmed). Drives whether an instance is shared across models (`true`) or pinned to one model at launch (`false`) — see §4.3.
- **`supports_goose_extensions`** (bool, default `false`, **new — separates a concern the original draft conflated with `supports_live_config`**) — whether this harness understands Goose's private custom ACP methods (`_goose/unstable/...`). Goose itself: `true`. A bare `claude-agent-acp` process: `false`, even though it may independently support the *standard* ACP `session/set_config_option` (i.e. `supports_live_config` and `supports_goose_extensions` are orthogonal, not the same bit — see §6.4).

### 4.3 New collection `harness_instances` — runtime container tracking

Tracks containers PocketBase has actually provisioned (or, for the compose-managed default Goose, is aware of), distinct from the static `harnesses` catalog. A row exists once any chat has selected that harness (or harness+model combo), whether or not the container is currently up.

| Field | Type | Notes |
|---|---|---|
| `id` | text (PB-owned PK) | |
| `harness` | relation → `harnesses`, required | |
| `harness_model` | relation → `harness_models`, not required | denormalized convenience for `expand` only — **not** the uniqueness key, see below |
| `launch_key` | text, required | `""` for a `supports_live_config = true` harness (one instance serves every model); otherwise the `harness_models.id` this instance was launched with. This, not `harness_model`, is what uniqueness is keyed on — see rationale below |
| `container_name` | text, required | the actual Docker container name |
| `acp_endpoint` | text, not required | e.g. `ws://<container_name>:3000/acp`; **empty means "use `Coordinator.Config` defaults"** — this is how the compose-managed Goose is represented (§5.6.3), not as a special case in code |
| `status` | select: `pending`\|`running`\|`stopped`\|`error` | updated by the event watcher (§5.3) |
| `last_error` | text | e.g. `"No such image"` — surfaces §5.1.1 failures to an admin instead of a silent stuck `pending`/`error` row |
| `managed` | bool, default `false` | `true` = PocketBase created this container and may stop/remove it; `false` = compose-managed (the default Goose) and must never be touched by the provisioning/reconciliation code |
| `created` / `updated` | autodate | not present on `harnesses` today; added here because instance lifecycle (and future idle-stop work, §7) needs timestamps |

Indexes:
```
CREATE UNIQUE INDEX idx_harness_instances_name ON harness_instances (container_name)
CREATE UNIQUE INDEX idx_harness_instances_pair ON harness_instances (harness, launch_key)
```

**Why `launch_key` (a required text sentinel) instead of a nullable `harness_model` relation for the uniqueness key** — corrects a factual error in the original draft. PocketBase does **not** store an unset single relation as SQL `NULL`: `RelationField.ColumnType` (`core/field_relation.go`) is `"TEXT DEFAULT '' NOT NULL"` for a non-multiple relation, so an unset `harness_model` is the empty string `''`, which compares equal to `''` under a unique index exactly as you'd want — a naive `UNIQUE(harness, harness_model)` would in fact have worked, no app-level race needed. `launch_key` is used anyway, not `harness_model` itself, because it's self-documenting (the column name states what it means: "the part of the config frozen into the container at create time") and it's the natural place to extend to a third pinning axis later (e.g. a sandbox profile) without another schema decision — `launch_key` would just become a hash of the frozen launch config, no index change required. `harness_model` stays purely for `expand` convenience in the API/UI.

API rules for this new collection (the original draft omitted these — a new collection with unset rules is invisible to the client, which breaks §6): `listRule`/`viewRule`: `"@request.auth.id != ''"` (matches `harnesses`); `createRule`/`updateRule`/`deleteRule`: `null` (superuser/backend-only — PocketBase's own provisioning code writes these, not end users).

## 5. Runtime behavior

### 5.1 Chat → instance resolution

`buildSessionProfile` resolves, in order: `chat.harness` if set, else `harness_models.harness` of the resolved model (`chat.harness_model_override` or the poco's `harness_model`), else the implicit default (today's single Goose). It then looks up the matching `harness_instances` row (keyed on `(harness, launch_key)` — `launch_key` is `""` unless the harness has `supports_live_config = false`, in which case it's the resolved `harness_models.id`). If no row exists, provision one (§5.1.1/§5.1.2) before dialing.

#### 5.1.1 Getting the image onto the box

`docker-socket-proxy-write` currently has `IMAGES=0`. `POST /containers/create` fails with "No such image" if the image isn't already local, and there is no pull path with `IMAGES=0`. This spec picks: **flip `IMAGES=1` on `docker-socket-proxy-write`.** This is a real proxy config change (the original draft incorrectly claimed none was needed) but a defensible one: `harnesses.container_image` is only ever superuser-written (§3), so the proxy would only ever be asked to pull images an admin already put in the catalog, not arbitrary end-user strings — consistent with the single-user-VPS trust model this whole spec leans on elsewhere. `harness_instances.last_error` (§4.3) surfaces a failed pull/create instead of it disappearing into a stuck `pending` row.

#### 5.1.2 Resolving the real volume/network names

`goose_workspace` and `pocketcoder-agent` are declared without `name:`/`external: true`, so the real Docker object names are compose-project-prefixed and not knowable at compile time — and they will differ between a dev checkout and an Aeroform-provisioned box. Passing a wrong **volume** name to `POST /containers/create` does not error — Docker silently creates a new, empty volume, and the harness comes up "successfully" pointed at an empty `/workspace`. A wrong **network** name does at least error.

Fix: at PocketBase startup, `GET /containers/pocketcoder-pocketbase/json` (allowed under `CONTAINERS=1`) and read the real volume name from `Mounts[]` and the real network name from `NetworkSettings.Networks`; cache both for use in every subsequent `harness_instances` create. (Pinning explicit `name:` values in `docker-compose.yml` for both objects is a simpler alternative and worth doing anyway for operational clarity, but doesn't remove the need to handle a not-yet-migrated existing deployment, so the runtime resolution stays regardless.)

`NETWORKS=0` also blocks `POST /networks/{id}/connect` — meaning the network **must** be attached via `NetworkingConfig` in the container-create call itself, not as a follow-up call. `launch_template` rendering must account for this.

### 5.2 What a fresh box looks like, and the default-Goose row

The implicit default (no `chat.harness` and no resolvable `harness_models.harness`) still means "today's compose-managed Goose," represented as a **seeded** `harness_instances` row: `harness` → the seeded `goose` catalog row, `managed = false`, `container_name = "pocketcoder-goose"`, `acp_endpoint = ""` (meaning: use `Coordinator.Config`'s existing `GooseURL`/`GooseSecret`, not a resolved instance URL). This removes the special-case branch that "the default case still resolves to today's single Goose instance" would otherwise require in code — resolution always ends at a `harness_instances` row, full stop; that row's `managed = false` is what tells the reconciliation/teardown code in §5.3 never to touch it.

### 5.3 Reactive status tracking

A watcher subscribes to the Docker event stream via `EVENTS=1` and updates the matching `harness_instances.status` on container start/die/health-change — **but subscribe first, then sweep**: on PocketBase startup, subscribe to `/events` before running a one-time `GET /containers/json?all=1` reconciliation pass, so a container that died while PocketBase was down (which would otherwise leave its row stuck at `running` forever, since no event was ever consumed for it) gets corrected without a gap where an event fires between the sweep and the subscription. The sweep, and any stop/remove the watcher ever issues, must skip every row with `managed = false`.

### 5.4 stdio-transport harnesses (no longer out of scope)

`claude-agent-acp`/`claude-code-acp` — §1's own motivating example — is stdio-transport. Excluding it (as the original draft did) means v1 can't run the harness that justified building it. `EXEC=0` on the proxy blocks `docker exec`, but not container **attach**: `POST /containers/{id}/attach?stream=1&stdin=1&stdout=1` gives a hijacked bidirectional stream to the container's PID 1, and it's covered by the `CONTAINERS`+`POST` ACL already granted. A `stdio` harness's `harness_instances` row still gets a `container_name` (for attach) but `acp_endpoint` stays empty (there's no network endpoint); the coordinator's `Dial` (§6.1) gains an attach-stream variant alongside the existing `acp.DialConfig{URL, Secret}` websocket path, selected by the resolved harness's `acp_transport`.

### 5.5 What stays Goose-only in v1

`AdminConn` (tool-permission live delivery, MCP gateway attachment, schedule import, Cognee extension wiring, skills, schedules — nine call sites, §2) stays pinned to the compose-managed Goose instance. Non-Goose harnesses do not get any of this in v1 — explicitly documented here so it isn't discovered as a surprise gap during implementation. A consequence worth stating plainly: because a non-Goose harness's provider keys are baked into its `launch_template.env_template` at container-**create** time (there is no per-session or config-render-and-restart path for it, unlike Goose's `keys.env`), **rotating a provider key for a non-Goose harness means destroying and recreating its container**, not a restart. This is a real regression relative to Goose's rotation story and is accepted for v1, not solved.

### 5.6 Session identity and harness pinning

`goose_sessions` has `UNIQUE(chat)` and `UNIQUE(goose_session_id)` (§2) — a chat's session id is minted once, by one specific harness process, and is only loadable there. If a chat's effective harness could change after that id was minted, the coordinator would issue `LoadSession` against a harness that never saw the id, and there is no recovery: the unique index blocks writing a replacement row. The original draft of this spec did not account for `goose_sessions` at all; this is the most important correction in this revision.

**Decision: pin harness at chat creation, don't support re-homing a chat to a different harness in v1.** A hook on `chats` rejects any update to `harness` (or to `harness_model_override`/`poco_config` in a way that would change the *resolved harness*, not just the model) once a `goose_sessions` row exists for that chat. The model may still change freely within the pinned harness — that's the already-working live-config path (§2) and is unaffected.

Even though re-homing isn't supported in v1, add `goose_sessions.harness_instance` (relation → `harness_instances`, not required) **now**, populated on every new session going forward. Retrofitting this field after rows exist without it is the expensive kind of change; adding it unused-but-populated today is not. `delete_session.go`'s `FindFirstRecordByFilter("goose_sessions", "chat = {:chat}")` needs no change under the pin-at-creation decision (still exactly one row per chat), but the added field means a future re-homing design (a real `UNIQUE(chat, harness_instance)` + per-instance session lookup) starts from populated data instead of a backfill.

#### 5.6.1 Harness is not derived from model alone

Resolving harness only via `harness_model_override → harness_models.harness` (the original draft's only path) makes a harness with zero `harness_models` rows unselectable, and puts "pick a model" ahead of "pick a harness" — backwards relative to §1's terminal analogy (pick the binary, then configure it). `chats.harness` (§4.1) fixes this: it is the primary signal; `harness_models.harness` is only consulted as a fallback when `chats.harness` is unset but a model override is. A `chats` validation hook checks the two agree when both are set (`chat.harness_model_override`'s harness must equal `chat.harness`, when both are non-empty) and rejects the write otherwise.

### 5.7 Interaction with `poco_configs.workspace_folders`

`workspace_override` overrides **only element 0 (cwd)**; `AdditionalDirectories` is always the union of the poco's `workspace_folders[1:]` regardless of whether `workspace_override` is set. This matches the terminal mental model from §1 — "I `cd`'d somewhere else, my existing tooling directories still apply" — and avoids a user's cwd choice silently dropping a poco's configured additional directories.

### 5.8 Path validation on `workspace_override`

Moving cwd from `poco_configs` (superuser-only: `createRule`/`updateRule: null`) onto `chats` (writable by the chat's owning user, and by the `agent` role per its existing update rule) is a real privilege change, not a neutral relocation: it lets an authenticated user, or the agent process itself, set the next session's cwd to an arbitrary path — including `/goose` where `keys.env` (every provider API key) lives. A `chats` create/update hook rejects any `workspace_override` entry that, after `filepath.Clean` and symlink-aware resolution, is not contained under the workspace root (`GOOSE_WORKSPACE`, default `/workspace`). This is a required part of this spec, not a follow-up, and is covered explicitly in §7's test list.

### 5.9 Constrained combinations

`harness_models` already constrains which models are valid for which harness (unique on `(harness, model)`) — the client only offers models that have a row there for the selected harness. A model additionally requires the current user to have a `provider_keys` row for that model's `provider`; `models.provider` and `provider_keys.provider` are both plain, uncanonicalized text (no shared enum), so the client-visible filter in this design makes a casing/naming mismatch (`Anthropic` vs `anthropic`) user-visible as "my model list is empty" for the first time — worth normalizing on write in a future pass, noted here rather than solved (§7 open items).

## 6. Coordinator changes (the actual surgery, spelled out)

The original draft's "`Coordinator.Config.GooseURL` becomes a per-chat resolved value" undersold this as a one-line change; it's a signature change plus several call sites, listed here so implementation doesn't discover the scope mid-flight.

### 6.1 `DialFunc` gains a resolved target

`type DialFunc func(context.Context, acpsdk.Client) (acp.Conn, error)` becomes `func(context.Context, acpsdk.Client, Target) (acp.Conn, error)`, where `Target{URL, Secret, Transport, ContainerName string}` comes from the resolved `harness_instances` row (empty `Target` falls back to today's `Config.GooseURL`/`GooseSecret`, preserving existing single-Goose deployments unmodified).

### 6.2 Both dial call sites need the resolved profile before dialing

`StreamColdReplay` (`run.go:547`) and `runLoop` (`run.go:726`) both already resolve `SessionProfile` before dialing (`run.go:542` before `547`; `run.go:712` before `726`), so threading `Target` through `SessionProfile` (a new `SessionProfile.Target` field, populated by `buildSessionProfile`'s resolution in §5.1) works without reordering either path.

### 6.3 Workspace fallback

`c.config.Workspace` is the cwd fallback at `run.go:556-559` and `run.go:780-783`. This design mandates every catalog harness mount its workspace at the same path (`/workspace`) as Goose does, so the existing single fallback constant remains correct; a harness needing a different mount path is out of scope for v1.

### 6.4 `selectApplier` must actually branch

`selectApplier` unconditionally returning `PerSessionApplier` (§2) is fine with one harness and a live bug with two: a harness with `supports_goose_extensions = false` will reject the `_goose/unstable/session/system-prompt/set` call at `profile.go:130`, `Apply` returns an error, and that error propagates out of `initSession` (`run.go:818-820`), killing the entire run. `selectApplier` must consult the resolved harness's `supports_live_config`/`supports_goose_extensions` (not just the ACP `InitializeResponse` capabilities, which only tell you about standard ACP surface, not Goose's private extensions) and skip the system-prompt call for `supports_goose_extensions = false` harnesses, applying only standard `session/set_config_option` calls gated by `supports_live_config`.

## 7. Client-facing surface

`ChatDao.save`/`createChat` gains optional `harness`, `harnessModel`, and `workspaceOverride` parameters, threaded from a new chat-creation step in `chat_list_cubit.dart`/`chat_list_screen.dart` that lets the user pick cwd + harness + model before the chat is created (today it's a bare title-only insert). This is the actual point where "the user chooses, like terminal Claude Code" becomes real — everything upstream in this spec exists to make that choice mean something.

## 8. Testing

- **`buildSessionProfile` fix (§2)**: a chat with `harness_model_override`/`workspace_override`/`harness` set but **no** `poco_config` and **no** `is_default` poco (the fresh-deployment state) must still resolve those chat-level fields — this is the regression test for the early-return bug, and it should fail against today's code before the fix lands.
- **Harness pinning (§5.6)**: a chat whose resolved harness would differ from the harness that minted its existing `goose_sessions` row must be **rejected at the hook**, not surfaced as a runtime `LoadSession` failure. Write this test so it is impossible to construct a passing case that reaches `LoadSession` with a mismatched harness — that's the point of pinning at creation instead of at use.
- **`selectApplier` branching (§6.4)**: against a harness with `supports_goose_extensions = false`, assert no `_goose/unstable/...` call is issued and the run does not fail; against `supports_live_config = false`, assert no `session/set_config_option` call is issued either.
- **Instance resolution**: fake docker-socket-proxy client — first-time chat→harness selection provisions exactly one instance (reused for a second chat on a `supports_live_config = true` harness; a second distinct instance, keyed on `launch_key`, for a `supports_live_config = false` harness with a different model). Include a case for `IMAGES=0`-style pull failure surfacing into `harness_instances.last_error` rather than a silently stuck row.
- **Volume/network resolution (§5.1.2)**: a fake `GET /containers/pocketcoder-pocketbase/json` response drives the cached volume/network names used in a subsequent create call — assert the wrong-name-silently-creates-empty-volume failure mode is what this test is guarding against (i.e. assert the *resolved* name is used, not a guessed one).
- **Event watcher (§5.3)**: fake Docker event stream — a `die` event flips the matching row to `stopped`, a healthy `start` flips it to `running`; a startup reconciliation sweep corrects a row left `running` from a container that died while PocketBase was down; both the sweep and any stop/remove skip `managed = false` rows.
- **Path validation (§5.8)**: `workspace_override` entries outside the workspace root (including via `..` traversal and symlink escape) are rejected by the `chats` hook.
- **Client**: existing chat-creation tests extended to cover the new optional params defaulting to today's behavior when omitted (backward-compatible bare-title creation still works).

## 9. Open questions / risks carried forward

- **Resource footprint, reweighted.** Each non-Goose harness instance is another always-on daemon, and per §5.1.1 its image must already be pulled onto a possibly modest VPS — disk, not just RAM, is now a binding constraint, and it interacts directly with `docs/superpowers/specs/2026-07-29-linode-boot-time-image-provisioning-design.md`. No lazy-stop-when-idle mechanism is designed here (the `created`/`updated` fields on `harness_instances` exist partly to make that easy to add later); the first real non-Goose harness should validate whether this matters in practice before building one.
- **Provider string normalization** (§5.9): `models.provider`/`provider_keys.provider` casing/naming consistency is not enforced anywhere today; this design makes a mismatch user-visible for the first time via client-side filtering. Worth a normalize-on-write hook in a follow-up, not solved here.
- **Migration mechanics.** Per `CLAUDE.md`, schema changes land by editing `schema.json` directly and re-running the export/generate pipeline. Every change in §4 is additive (new fields, new collection, new indexes on previously-unindexed or newly-created columns) — there is no unique-index change on populated data, which was the risk §5.6's pinning decision was specifically chosen to avoid. If a future revision needs to support re-homing a chat to a different harness, that is the point where `goose_sessions`' unique indexes would need to change, and it should get its own design pass rather than being folded in casually.
- **Per-chat worktree convenience**: still explicitly deferred (§3). If stomping between chats sharing a `workspace_override` value becomes a real complaint, a future PocketBase-side "create me a worktree" action is the natural next step, not automatic isolation.
