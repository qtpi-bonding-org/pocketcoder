# Scheduler UI + Retirement — Design

## Problem

Goose has a full scheduler (`_goose/unstable/schedules/*`) that runs recipes on
a cron schedule inside its own process. PocketCoder has no working UI for it
and instead ships a bespoke, broken cron feature (`cron_jobs` collection,
`internal/api/cron.go`, `internal/hooks/cron.go`) left over from the
OpenCode era. That feature is not merely obsolete — it errors at runtime: it
creates a message via `app.FindCollectionByNameOrId("messages")`, a
collection deleted in `1752000000_prune_legacy_runtime.go`, and it filters
`chats` by `ai_engine_session_id` and sets `chats.agent`, both fields also
deleted. `main.go:71,85` still registers both halves.

This is the last unspecced item of the original "foundational trio" of
deferred-UI decompositions (`spikes/goose-acp-config-surface/ownership-map.md`),
alongside MCP governance UI (shipped) and Tool-Permissions UI (shipped).

## Prior research (cited, not re-derived)

- `ownership-map.md` buckets the scheduler as Bucket B (Goose fully owns
  state, exposes full read+write over ACP) but its Opus review correction
  #4 flags that goose-native scheduled runs produce sessions that never
  reach PocketCoder's chat/notification pipeline on their own — real
  integration work, not just an ownership row.
- Goose's real ACP surface (`.independent_repos/goose_reference`, pinned
  v1.43.0, `crates/goose/acp-meta.json` + `acp-schema.json`):
  `_goose/unstable/schedules/{list,create,update,delete,pause,unpause,
  run-now,sessions/list}` plus `running-job/{kill,inspect}`.
  - `ScheduledJobDto`: `{id, source, cron, lastRun, currentlyRunning,
    paused, currentSessionId, jobStartTime}` — `id` and `cron` required.
    `id` is the schedule's own identifier, validated server-side
    (`acp/server/schedule.rs::validate_schedule_id`) to be alnum, `-`, `_`,
    or space only. It is immutable — no rename operation exists.
  - `CreateScheduleRequest_unstable` requires `{id, recipe: RecipeDto,
    cron}`. `RecipeDto` requires only `{title, description}` — `prompt` is
    optional but is what actually drives the run. No `cwd`/workspace field
    exists on `RecipeDto` — scheduled runs execute in Goose's own default
    working directory, not a chosen `poco_config`.
  - `UpdateScheduleRequest_unstable` takes only `{scheduleId, cron}` — the
    recipe itself cannot be edited after creation via this API.
  - `ListScheduleSessionsRequest_unstable` returns `sessions: SessionInfo[]`
    (`{sessionId, cwd, title, updatedAt, ...}`) per schedule — an index of
    session ids, not message content.
- PocketBase has **no `messages` table** (deleted in
  `1752000000_prune_legacy_runtime.go`) and never persists chat history.
  Live chats work by dialing Goose and materializing `session/update`
  notifications into AG-UI events on the fly
  (`internal/agent/agui/bridge.go:76`). Reconnecting/cold clients replay the
  same way: `StreamColdReplay` (`coordinator/run.go:508-553`) dials Goose,
  registers the client callback, then calls standard-ACP `session/load`,
  which delivers full history as a burst of `session/update` notifications
  (not in the response body — confirmed against the vendored
  `acp-go-sdk@v0.13.5`, `LoadSessionResponse` carries only
  `configOptions`/`modes`).
  **Consequence: "importing" a scheduled run's session requires no new
  message-persistence code.** Creating a `chats` row + a `goose_sessions`
  row pointing at that session id is sufficient — opening the chat replays
  its content through the exact mechanism already used for reconnects.
- `goose_sessions` (`1748000500_goose_sessions.go`) is the only c1↔Goose
  session mapping: `{chat (relation, required, cascade), user (relation,
  required, cascade), goose_session_id (text, required), goose_version,
  provider}`, with **unique indexes on both `chat` and `goose_session_id`**
  — one Goose session per chat, enforced at the DB level. This unique index
  on `goose_session_id` is reused below as the dedup mechanism for the
  importer (an already-imported session simply fails/no-ops on re-insert).
- `chats` (`1740000100_consolidated_schema.go`, as pruned by
  `1752000000_prune_legacy_runtime.go` and `1753000000_prune_legacy_ai_config.go`)
  requires `title` and `user`; has no session-id field of its own (that
  lives on `goose_sessions`) and no `agent` field (deleted).
  `internal/hooks/notifications.go:175`,
  `SendPushNotification(app, userID, title, message, notifType, chatID)`,
  is the one dispatch entry point for push notifications — it is not
  triggered by record hooks (`RegisterNotificationHooks` is an empty stub),
  so any caller wanting a notification must invoke it directly.
- `app.Cron()` (PocketBase's built-in scheduler) is registered and
  functional (`internal/hooks/cron.go:43-47`) — the dead cron feature's
  bug is entirely in what it does when a job fires, not in the scheduler
  registration itself. This spec reuses `app.Cron()` for the new
  background importer; no new polling infrastructure is needed.
- `AdminConn` (`coordinator/admin.go`) already exists and already lists
  "schedules" in its own doc comment as an anticipated consumer — the
  session-free per-request ACP connection this spec's routes and importer
  both use.
- **PocketBase-vs-Goose ownership rule** (now documented in root
  `CLAUDE.md`): PocketBase always owns its own primary key; an external
  system's identifier is stored as a plain (usually unique-indexed) field,
  never repurposed as the PK. This resolves the schedule-rename question
  below — see Component 1.

## Architecture

```
Flutter → POST /api/pocketcoder/schedules/{list,create,update,pause,unpause,delete,run-now}
        → schedules.go (new) → AdminConn → _goose/unstable/schedules/*

app.Cron() (every 60s) → schedule_importer.go (new) → AdminConn
  → for each schedule_owners row: schedules/sessions/list
  → for each unseen sessionId (dedup via goose_sessions unique index):
      create chats row (owner = schedule_owners.user) + goose_sessions row
      → hooks.SendPushNotification
```

Two independent pieces: (1) synchronous CRUD routes the Flutter Scheduler
screen calls directly, and (2) an asynchronous background importer that
notices when a schedule has fired and turns the resulting Goose session
into a normal, visible PocketCoder chat. Neither depends on the other at
request time — CRUD works even if the importer hasn't run yet; the importer
only needs `schedule_owners` rows, which CRUD's `create` route writes.

## Component 1: `schedule_owners` schema

New collection, PocketBase-owned identity (own auto `id`), one field per
piece of information Goose cannot express:

```go
collection := core.NewBaseCollection("schedule_owners")
collection.Fields.Add(
    &core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1, CascadeDelete: true},
    &core.TextField{Name: "goose_schedule_id", Required: true},
    &core.TextField{Name: "display_name", Required: true},
)
collection.Indexes = []string{
    "CREATE UNIQUE INDEX idx_schedule_owners_goose_schedule_id ON schedule_owners (goose_schedule_id)",
}
```

- `goose_schedule_id`: the immutable identifier passed to every
  `_goose/unstable/schedules/*` call. Generated server-side at creation
  time (a random opaque string satisfying `validate_schedule_id`'s
  alnum/hyphen/underscore/space rule — reuse PocketBase's own random-id
  generator, `security.PseudorandomString` or equivalent, rather than
  inventing a new one), **not** user-supplied — the user never sees or
  edits it.
- `display_name`: what the user actually types and can rename freely,
  purely a PocketBase-side label. Renaming only touches this row; it never
  calls Goose (there is no rename RPC).
- `user`: per-user ownership, per the user's explicit confirmation that
  schedules must be scoped like chats are (a schedule's resulting chats
  need a real owner — there's no "global chat" concept to fall back on the
  way there is for Settings-only screens like Tool-Permissions/MCP).

List rule mirrors `goose_sessions`: `@request.auth.id != '' && user =
@request.auth.id`.

## Component 2: Go routes (`internal/api/schedules.go`, new)

Mirrors `skills.go`'s shape (per-request `AdminConn`, JSON bind/response,
role check). Routes, all under `/api/pocketcoder/schedules/`, all
`RequireAuth()` + owning-user check (not admin-only — schedules are
per-user, unlike Skills/Tool-Permissions/MCP which are household-global
Settings screens):

- `POST list` — no ACP call needed for the list itself beyond
  `schedules/list`; join against the caller's own `schedule_owners` rows
  (filter to schedules the caller owns — `schedules/list` returns every
  schedule in the flat Goose namespace, so PocketBase must filter it to
  the caller's own `goose_schedule_id`s before returning). Response
  per schedule: `{id (schedule_owners record id), displayName, cron,
  paused, currentlyRunning, lastRun}` — merges the PocketBase row with the
  matching `ScheduledJobDto`.
- `POST create` — body `{displayName, cron, prompt}`. Generates a fresh
  `goose_schedule_id`, calls `schedules/create` with
  `{id: goose_schedule_id, cron, recipe: {title: displayName, description:
  displayName, prompt}}`, then on success creates the `schedule_owners`
  row. If the `schedule_owners` write fails after a successful Goose
  create, best-effort call `schedules/delete` to avoid an orphaned
  Goose-side schedule with no owner.
- `POST rename` — body `{id, displayName}`. PocketBase-only: updates
  `schedule_owners.display_name`. No Goose call.
- `POST update-cron` — body `{id, cron}`. Looks up `goose_schedule_id` from
  the `schedule_owners` row, calls `schedules/update`.
- `POST pause` / `POST unpause` — body `{id}`. Looks up
  `goose_schedule_id`, calls the matching RPC.
- `POST delete` — body `{id}`. Calls `schedules/delete` with the resolved
  `goose_schedule_id`, then deletes the `schedule_owners` row. Does not
  touch any already-imported `chats`/`goose_sessions` rows from past runs
  — those stay as ordinary chat history.
- `POST run-now` — body `{id}`. Calls `schedules/run-now`. Does not itself
  create a chat — the background importer (Component 3) picks up the
  resulting session on its next poll, same as a cron-triggered fire. This
  keeps there being exactly one code path that creates imported chats.

Every route resolves `id → goose_schedule_id` via a `schedule_owners`
lookup filtered to `user = re.Auth.Id`, so a user can never operate on a
schedule they don't own (404, not 403, on a foreign id — don't leak
existence).

## Component 3: Background importer (`internal/hooks/schedule_importer.go`, new)

Registered in `RegisterCronHooks`'s startup path (or a new sibling
`RegisterScheduleImportHooks`, called once from `main.go` next to the
existing `hooks.RegisterCronHooks(app)` line — replacing it, since cron.go
itself is deleted per Retirement below) via `app.Cron().Add("schedule-import",
"* * * * *", importFn)` — every minute, PocketBase's existing cron syntax.

`importFn`:
1. `app.FindRecordsByFilter("schedule_owners", "1=1", "", 0, 0)` — all
   owned schedules across all users (this is a background job, not a
   per-request handler; it legitimately needs the full table).
2. Dial one `AdminConn` for the whole run (per the ownership-map's
   "connection lifetime = one request" guidance, extended here to "one
   poll pass").
3. For each row, call `schedules/sessions/list` with
   `{scheduleId: goose_schedule_id, limit: 20}`.
4. For each returned `sessionId`, check `app.FindFirstRecordByFilter(
   "goose_sessions", "goose_session_id = {:id}", ...)`. If found, skip
   (already imported). If not:
   - Create a `chats` row: `title` = the schedule's `display_name` + a
     timestamp (matches the old cron feature's title format,
     `"%s — %s"`), `user` = `schedule_owners.user`.
   - Create a `goose_sessions` row linking `chat` → that `sessionId`
     (`provider`/`goose_version` left blank — not known from
     `schedules/sessions/list`'s response, and not required fields).
   - Call `hooks.SendPushNotification(app, ownerUserID, displayName,
     "Scheduled task finished", "schedule", chatID)`.
5. Log and continue past any single row's error — one broken schedule
   must not block importing the rest.

This uses the existing unique index on `goose_sessions.goose_session_id`
as its sole dedup mechanism — no separate "seen sessions" cursor/state is
needed, since the check in step 4 already excludes anything previously
imported, and a duplicate `app.Save` would fail the unique constraint
regardless as a backstop.

## Component 4: Flutter (`lib/presentation/scheduler/`, new)

Same shape as `SkillsScreen`/`ToolPermissionsScreen`: `Skill`-style domain
model (no `id`/`fromRecord` needed here since routes return plain JSON —
model is `{id, displayName, cron, paused, currentlyRunning, lastRun}`,
`fromJson` only), `ISchedulerRepository`/`SchedulerRepository` (calls the
routes above via `PocketBase.send()`, each wrapped in `tryMethod` /
`SchedulerException`), `SchedulerCubit`/`SchedulerState` (one-shot
`loadSchedules()` + `createSchedule()`/`renameSchedule()`/
`updateCron()`/`pauseSchedule()`/`unpauseSchedule()`/`deleteSchedule()`/
`runNow()`, each mutation re-calling `loadSchedules()` after success),
`SchedulerScreen` (list with pause/unpause toggle, RUN NOW / RENAME /
DELETE buttons per row, ADD dialog with `displayName` + `cron` + `prompt`
free-text fields — no cron-builder widget, matching the free-text
precedent from Tool-Permissions UI). New route
`AppRoutes.configureScheduler` / `/configure/scheduler`, wired into
Settings the same way Skills UI's route is (this spec's own plan re-derives
the exact `settings_screen.dart`/`app_router.dart` diff against
current-at-implementation-time state, per this repo's established
plan-writing convention).

Imported chats need no new Flutter code at all — they're ordinary `chats`
rows and appear in the existing chat list/screen unmodified.

## Retirement

Delete:
- `services/pocketbase/internal/api/cron.go`
- `services/pocketbase/internal/hooks/cron.go`
- Their `main.go:71,85` registrations (replaced by Component 3's new
  registration call)
- `cron_jobs` PocketBase collection (new migration; check for surviving
  relations first — `chats` had no relation *to* `cron_jobs`, only
  `cron_jobs → chats`/`cron_jobs → poco_config`, so no other collection
  needs a relation dropped first, but this must be re-verified against
  the schema at implementation time the same way Skills UI's Task 4 did)
- `client/packages/pocketcoder_flutter/lib/domain/models/cron_job.dart`
  (+ generated `.freezed.dart`/`.g.dart`) — confirm zero references outside
  its own generated files before deleting, same check Skills UI's plan
  ran for `skill.dart`.

## Out of scope

- Editing a schedule's recipe/prompt after creation — Goose's
  `schedules/update` only accepts a new `cron`, matching this spec's
  `update-cron` route; there is no `update-prompt` capability to build a
  route for.
- A cron-expression builder/preset UI — free text only, consistent with
  this repo's established "free text over structured picker" precedent.
- `running-job/kill` and `running-job/inspect` (cancelling or inspecting
  a currently-*executing* run, distinct from viewing a *finished* run's
  imported chat) — deferred; `run-now`'s existing `currentlyRunning` field
  in the list response is enough to show a run is in progress without
  building cancel/inspect UI for it yet.
- Recipe authoring beyond the single `prompt` field (extensions,
  parameters, sub-recipes, retry config) — `RecipeDto`'s full surface is
  intentionally not exposed; this spec only ever constructs the minimal
  `{title, description, prompt}` shape.
