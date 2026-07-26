# Goose ownership map: what PocketBase must persist vs. pure passthrough

Follow-on to `README.md` in this directory (the original provider/model/prompt/
mode/permissions/keys spike). This doc answers the bigger question raised
after that one: if PocketCoder wants to expose *all* of Goose's config
surface through PocketBase to Flutter, what is the minimum PocketBase must
persist, versus what can be a pure live passthrough with no PocketBase
storage at all?

Same method: read Goose v1.43.0 source directly
(`.independent_repos/goose_reference`, gitignored, not committed), catalog
every ACP method (standard + `_goose/unstable/*`) the server exposes, and
cross-reference against everything Goose persists to disk.

## Correction to the original spike

The original spike concluded tool-permission policy needed a forced
PocketBase-side mirror because no read-back method existed. That was based
on an incomplete grep. Two corrections:

1. **`permissions/tool_permissions.json`** (the "interactive decision cache"
   flagged as a precedence risk) **is dead code** — grepped the entire
   runtime, it's never read or written by anything in the live request path.
   `PermissionInspector::inspect` never references it. Ignore it entirely;
   only `permission.yaml` (via `PermissionManager`) is real.
2. **A read-back does exist**: `_goose/unstable/tools/list` returns each
   tool's current permission level, sourced from the same
   `PermissionManager`. So tool-permission policy does NOT need a forced
   PocketBase mirror after all — see Bucket B below.

## Full ACP method catalog (99 methods total)

7 standard ACP methods + `session/delete` (standard-shaped but dispatched
through the custom-request path) + 91 `_goose/unstable/*` custom methods.
Grouped by resource area; full table with method names, read/write, and
file:line evidence lives in the session transcript this doc was generated
from — the summary below is what matters for the ownership decision.
Resource areas found: session lifecycle, providers/models/secrets, generic
config/preferences, permissions & tools, MCP/extensions, apps (MCP-UI),
resources, prompt templates, recipes, scheduling, sources (skills / agents /
projects), diagnostics, dictation (voice), local inference. The last two are
irrelevant to PocketCoder (no UI, no use case).

## The four buckets

**Bucket A — Goose holds zero durable state. PocketBase must own it, no
shortcut available:** provider, model, per-chat system-prompt override,
permission mode. Ephemeral in Goose; gone when the session ends.

**Bucket B — Goose fully owns it AND exposes full read+write over ACP.**
Candidate for a zero-storage passthrough UI:
- Tool permission policy (`tools/list` read, `tools/permissions/set` write) — process-wide.
- MCP servers / extensions, global (`config/extensions/list,add,remove,set-enabled`) and per-session (`session/extensions/list,add,remove`).
- Skills (`sources/list,create,update,delete` with `type: skill`).
- Recipes (`recipes/list,save,delete`).
- Prompt templates (`config/prompts/list,get,save,reset` — Goose's own customizable built-in-prompt library, distinct from the per-chat instructions override).
- Scheduler (`schedules/list,create,update,delete,pause,unpause,run-now,kill,inspect`).

**Bucket C — Goose owns it, PocketBase mirrors read-only:** session/
conversation history (`session/list`, `session/load`) — already the
existing, correct design, unchanged.

**Bucket D — no ACP surface, CLI/internal-only, irrelevant to this
deployment:** plugins, `data_dir/projects.json` (distinct from
`data_dir/projects/*.md`, which IS reachable), logs, telemetry,
local-inference models, per-provider OAuth caches, TLS certs,
`adversary.md`, `history.txt`.

## The actual question: minimum PocketBase must own for Bucket B

"Fully passthrough-able" is not the same as "needs zero PocketBase data."
Two structural gaps show up even for pure-passthrough Bucket B items, and
they're the same shape as the one PocketBase already solves for Bucket C
(`chat_id → goose_session_id`):

### Gap 1 — Goose has no PocketCoder-identity concept

Every Bucket B resource lives in one flat, global namespace inside the one
goose process. Goose has no notion of "which PocketCoder user or chat this
belongs to." Anywhere PocketCoder's product needs that notion and Goose
doesn't model it, PocketBase must own the mapping — the content still lives
in Goose, only the *attribution/ownership* row lives in PocketBase:

| Bucket B item | What Goose has no concept of | Minimum PocketBase must own |
|---|---|---|
| MCP servers | Request/approve/deny/revoke workflow — Goose only has "enabled or not" | The full governance state machine: `requested_by, approved_by, approved_at, status, reason` (this is genuinely new functionality, not a mirror — it's the one item in this whole map that was correctly identified as real PocketCoder-side work from the start) |
| Scheduler | Which PocketCoder user/chat a scheduled job belongs to — a schedule entry just points at a recipe file, no user field | An ownership row: `goose_schedule_id → user_id / chat_id`, so "my scheduled tasks" can be rendered without every user seeing every schedule |
| Skills / Recipes | "Whose skill is this" / "shared vs. personal" — `sources/list` returns a flat filesystem listing, no owner | Only needed *if* per-user skill/recipe ownership is a real product requirement. If skills/recipes are meant to be deployment-wide (shared by the whole household), **no PocketBase row is needed at all** — pure passthrough. This is a product decision, not a technical constraint. |
| Tool permissions | N/A — this one is intentionally deployment-wide already (the "global for now" decision from the earlier conversation) | Optionally: an audit-log row (`who changed which tool's policy, when`) if you want history/accountability. Not required for the feature to work — `tools/list` already gives live current state. |

### Gap 2 — no standing connection to call these on

This is an infrastructure gap, not a data gap, but it's just as much a
"minimum requirement" as the schema questions above. Confirmed in
`services/pocketbase/internal/agent/coordinator/run.go`: every ACP
connection to Goose today is dialed per-run, tied to a specific chat's
active session (`conn, err := c.config.Dial(...)` inside the run-start path,
`run.go:534,713`). **There is no standing connection to Goose usable outside
an active chat.**

Every Bucket B custom method traced above takes no `session_id` — they're
connection-scoped, not session-scoped — so technically any live WS
connection to `goose:3000/acp` can call them. But if a user opens a
"Skills" or "Scheduled Tasks" settings screen with no chat currently
running, there is currently no connection for c1 to use. This means Bucket
B, as a Flutter feature, needs one new piece of coordinator-level
infrastructure that doesn't exist yet: **an on-demand (or persistent)
"admin" ACP connection to Goose, independent of any chat's session
lifecycle** — dialed when a config screen needs it (or kept warm, a
performance/complexity tradeoff to decide later), separate from the
existing per-chat `Hub`/session-scoped connections in `hub.go`/`run.go`.

### Bottom line

For Bucket B, the *minimum* required PocketBase schema is much smaller than
Bucket A:
- **MCP servers**: real schema required (governance workflow) — already
  exists as `mcp_servers`, keep it, but re-scope its job from "store the
  server config" to "store the approval workflow state," and change the
  delivery mechanism from the Docker-MCP-gateway/file+restart path to a
  direct `config/extensions/add` call once approved.
- **Scheduler**: one small ownership-mapping table
  (`goose_schedule_id ↔ user/chat`), nothing else. PocketCoder's existing
  bespoke cron feature (found broken in the earlier audit — references
  collections deleted by the Goose migration) should be retired in favor of
  this thin passthrough, not repaired.
- **Skills, recipes, prompt templates, tool permissions**: zero required
  schema. Optionally add ownership/audit rows if per-user scoping or
  history becomes an actual product requirement — not needed for the
  feature to function.
- **New infrastructure, not schema**: an admin/idle ACP connection path in
  the coordinator, since none of this works without one.

## Decisions (post Opus review — see "Corrections" section below)

- **MCP servers: yes, real schema.** Keep `mcp_servers`, re-scoped to pure
  governance state (`requested_by, approved_by, approved_at, status,
  reason`), delivered to Goose via `config/extensions/add` once approved —
  not the Docker-MCP-gateway/file+restart path. **Prerequisite, not
  optional:** PocketCoder's own `config.yaml` render must stop writing the
  `extensions` key at all, or a later unrelated config edit silently wipes
  out a live-added extension. Goose becomes the sole writer of that key.
- **Scheduler: yes, thin ownership table, but bigger than "thin."**
  `goose_schedule_id ↔ user/chat` is still required, but the plan must also
  import schedule-produced sessions into the normal chat/notification
  pipeline (`schedules/sessions/list` → `session/load` → the usual
  coordinator/events/notification path) — a goose-native scheduled run
  otherwise never reaches Flutter at all. Retire PocketCoder's existing
  bespoke/broken cron feature rather than repair it, but budget for this
  extra integration work, not just the ownership row.
- **Skills: zero PocketBase schema, pure passthrough.** Reconfirmed by
  independent review — holds as originally written.
- **Tool permissions: reverted — needs a light PocketBase mirror after
  all.** `tools/permissions/set` (write) is genuinely session-free, but
  `tools/list` (the only read-back) requires a live session — it 404s with
  none active, and a Settings screen shouldn't have to spin up a session
  just to render current policy. Keep a `tool_permissions` table as the
  render source (PocketBase already knows its own last-written state since
  it's the only writer), push full-state to `tools/permissions/set` live on
  every change, same shape as the original (pre-correction) spike
  concluded. Not a total reversal — writes are still live/no-restart, only
  the "zero schema" part was wrong.

### Skills, elaborated

Read `crates/goose/src/skills/mod.rs` and `client.rs` directly rather than
inferring. Two things resolve the "does this need per-user ownership"
question cleanly:

1. **Skills are already scoped by Goose itself, two ways — global or
   project.** `global_skills_dir() = ~/.agents/skills` (deployment-wide,
   lives under the `goose_data` volume via `GOOSE_PATH_ROOT`) vs.
   `project_skills_dir(project_dir) = <project_dir>/.agents/skills`
   (scoped to a specific working directory). PocketCoder's `poco_configs`
   already carries a `workspace_folders` concept — a project-scoped skill
   written to a chat's workspace folder is automatically only relevant to
   agents working in that folder, with **zero PocketBase schema required**
   to express that scoping. It falls out of a mechanism Goose already has.
2. **Skills are always-on, not explicitly attached like MCP extensions.**
   The "skills" platform extension is `default_enabled: true`
   (`agents/platform_extensions/mod.rs:198`) — every session automatically
   gets a `load_skill(name, args)` tool the model can call on demand
   (`skills/client.rs:62-69`). There's no per-agent "which skills does this
   poco_config use" attachment step the way there is for MCP servers — the
   model decides at runtime whether a skill is relevant and loads it. So
   there's no join-table concept to build even if we wanted one.

Net: skills need no PocketBase storage under either global or per-project
scoping. The only PocketBase-side work is a Flutter screen that calls
`sources/list|create|update|delete` (`type: skill`) directly through the
admin connection (see below), writing either to the global skills dir or a
specific chat's workspace-folder-scoped one depending on where the user
chooses to save it.

## Gap 2, elaborated: the admin connection

Confirmed in `coordinator/run.go`: `config.Dial(...)` is called per-run,
scoped to a specific chat's active session (`run.go:534,713`) — there is no
connection to Goose that exists independent of a chat being open. Every
Bucket B custom method takes no `session_id` (confirmed method-by-method
above), so nothing here technically needs a session — it needs *a live
WebSocket connection to `goose:3000/acp`, past the `initialize` handshake*,
full stop.

**Recommendation: ephemeral dial-per-request, not a standing connection.**

- Add `func (c *Coordinator) AdminConn(ctx context.Context) (acp.Conn, error)`
  that reuses the exact same `config.Dial` + `initializeRequest()` pattern
  already in `run.go`, but does **not** call `session/new` or `LoadSession`
  — just `initialize`, then whichever Bucket B RPC the caller needs, then
  close.
- No `session/new` also means the client-side ACP callback surface
  (`RequestPermission`, `SessionUpdate`, file/terminal ops — everything
  `sessionClient` in `run.go` implements) never fires for these calls, since
  none of them execute tools or run prompts. A minimal no-op client
  implementation is sufficient for the admin connection — it doesn't need
  `sessionClient`'s full behavior.
- Reject the standing-connection alternative for now: it would need
  reconnect/health-check logic and has to survive the goose container
  restarts that still happen on `provider_keys` changes — real complexity
  for a Settings screen that isn't on any latency-sensitive path. A fresh
  dial-per-action costs a connection + one `initialize` round trip
  (sub-second), which is a non-issue at PocketCoder's deployment scale.
  Revisit only if this specific path becomes an actual measured problem.
- **Connection lifetime = one incoming PocketBase request, not one ACP
  call.** If a single Flutter-facing request needs more than one Bucket B
  RPC to assemble its response (e.g. a screen that renders two related
  lists), dial once and reuse that connection for every call within that
  request, then close it when the request finishes — don't dial per RPC.
  Don't keep it beyond that request either — the next request (even a
  moment later, even for the same screen) dials fresh. This is the same
  shape the existing per-chat connections already use (one dial per run,
  reused for every call inside that run, closed at the end) — `AdminConn`
  just applies it to a request that isn't a chat run.

## Corrections from independent review (Opus, adversarial pass)

An independent review against the same source re-verified every claim
rather than trusting this doc, and found real problems — recorded here so
the reasoning survives, not just the corrected conclusion:

1. **`tools/list` requires an active `session_id`** (mandatory field,
   `custom_requests.rs`; 404s via `get_session_agent` with none active,
   `acp/server/tools.rs` + `acp/server.rs`) — it is not session-free. This
   is why the tool-permissions decision above was reverted.
2. **`config.yaml`'s `extensions` key is written by both Goose (via
   `config/extensions/add`, `crates/goose/src/config/extensions.rs`) and
   PocketCoder's own render (`gooseconfig.RenderConfigYAML`,
   `hooks/goose_config.go`)**, which does a full overwrite on every
   `poco_configs`/`provider_keys`/`tool_permissions`/`harness_models`/
   `prompts` CRUD event. Without removing `extensions` from PocketCoder's
   render, a live-added MCP server would get clobbered by the next
   unrelated edit.
3. **The method catalog undercounted**: hand-grepping `custom_requests.rs`
   found 91 custom methods; Goose ships **authoritative generated
   catalogs** — `crates/goose/acp-meta.json` and `crates/goose/acp-schema.json`
   — listing 114. Use those files directly for any future
   completeness-dependent audit instead of grepping source by hand. The 23
   missing methods include session-free generic `config/read|upsert|remove
   |read-all` and `defaults/*` calls, which weren't bucketed at all and
   touch the same `config.yaml` territory as point 2.
4. **Scheduler retirement undersells the integration work** — goose-native
   scheduled runs produce sessions inside the goose process that never
   touch PocketCoder's coordinator/events/notifications on their own; the
   plan needs to actively import them, not just track ownership.
5. **Multi-tenancy blast radius isn't unique to tool permissions** —
   `config/extensions/add` is equally process-wide (mutates live state for
   every active session/user on the one goose process). Worth one explicit
   "accepted for this deployment's scale" statement covering both, not two
   separate call-outs.
6. **No handling for the admin connection hitting goose mid-restart** —
   `provider_keys` edits still restart the container; a Settings action (or
   a config-extension write) issued during that window needs explicit
   retry/error handling, not a silent failure.

What held up under adversarial re-verification, unchanged: the
`tool_permissions.json` dead-code claim, the API-key env-var-precedence
claim, every skills claim, and session-free delivery for the rest of
Bucket B (sources/recipes/schedules/prompts, and the write half of
extensions/tool-permissions).

## Next step

Still not designed: the actual plan (schema migration for `mcp_servers`
re-scoping and the new scheduler ownership table, the `AdminConn` +
`ToolPermissionApplier`/`PerSessionApplier` coordinator changes, the Flutter
screens). This doc is the ownership-boundary input to that design — see the
parent conversation for where it lands next.
