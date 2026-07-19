# Cron-on-c1 Rewire — DRAFT Spec

**Date:** 2026-07-18
**Status:** DRAFT — capture only. Needs a full brainstorming pass before it earns an implementation plan. Do NOT execute from this document.
**Depends on:** Legacy Runtime Prune landing first. The prune leaves cron **broken on purpose** (loud errors on fire) — this rewire repairs it against the new agent path.

## Why this exists

Cron today triggers an agent run the legacy way: on fire it inserts a `role:user` record into the deleted **`messages`** collection and relies on the removed Interface event pump to forward it to OpenCode. The API also resolves the human user via the deleted **`chats.ai_engine_session_id`** field. After the prune, a firing job or a cron API call errors loudly (PocketBase still boots — cron callbacks only run on fire, the API filter only on request). This rewire makes a firing job drive a real **c1 agent run** through the coordinator.

## Current state (grounded)

**`internal/hooks/cron.go`** — registers `app.Cron().Add(...)` (line 110) → `executeCronJob` (line 123): re-fetches the job, reads `prompt`/`session_mode`/`user`, then:
- `session_mode == "existing"` → uses linked `chat` relation as `chatID` (147–151).
- `session_mode == "new"` → `createCronChat` creates a `chats` record, returns id (152–153).
- Then `createCronMessage(app, chatID, prompt)` (165) — **inserts into `messages`** (`chat`, `role:user`, `user_message_status:pending`, `parts` JSON; lines 217–223). No coordinator/ACP call. Status written back to the job via `updateCronJobStatus` (`last_executed`/`last_status`/`last_error`, 231–239).

**`internal/api/cron.go`** — `RegisterCronApi` (45), all routes `RequireAuth()` + `requireAgentOrAdmin`:
- `POST /api/pocketcoder/schedule_task` (47)
- `GET  /api/pocketcoder/scheduled_tasks` (119)
- `POST /api/pocketcoder/cancel_scheduled_task` (165)
- `resolveHumanUser(app, sessionID)` (201–217) reads deleted `chats.ai_engine_session_id` (204–208); called from `schedule_task` (77) and `scheduled_tasks` (129).

**`cron_jobs` schema** (`1740000100_consolidated_schema.go` §14, + `poco_config` added in `1748000100_acp_schema.go`): `name`, `description`, `cron_expression`, `prompt`, `session_mode` (existing/new), `chat`→chats, `agent`→agents, `user`→users (req), `enabled`, `last_executed`, `last_status`, `last_error`, `poco_config`→poco_configs.

**The new run entry point (what cron should call):**
```go
func (c *Coordinator) Run(ctx, req RunRequest, emit Emit, resolve ResolveSession, created OnSessionCreated) error   // run.go:270
func (c *Coordinator) RunReserved(ctx, req RunRequest, emit Emit, resolve ResolveSession, created OnSessionCreated) error // run.go:276
// RunRequest{ ChatID, Prompt string }; Emit func(events.Event) error;
// ResolveSession func(ctx) (string, error); OnSessionCreated func(ctx, string) error
```
Live call site: `POST .../chats/{chatId}/runs` in `api/agent.go:71` calls `RunReserved` with an SSE `emit`, `resolve = gooseSessionForChat(...)`, `created = saveGooseSession(...)`. The new path uses the **`goose_sessions`** collection (keyed `chat`+`user`), NOT `ai_engine_session_id`.

**Registration:** `hooks.RegisterCronHooks(app)` at `main.go:62`; `api.RegisterCronApi(app, e)` at `main.go:76`.

## What we know we want

- On fire, `executeCronJob` should call the **coordinator** (`Run`/`RunReserved`) for the resolved `chatID`, instead of inserting a `messages` record.
- Cron has no SSE client — the `emit` callback needs a **headless sink** (persist/log AG-UI events, or discard) since there's no HTTP response to stream to.
- `resolve`/`created` reuse the same `goose_sessions` mapping the live path uses (`gooseSessionForChat`/`saveGooseSession`), so a cron-run and a user-run on the same chat share one Goose session.
- Drop `resolveHumanUser`'s dependency on `ai_engine_session_id` (the field is gone); the job already carries `user` and `chat` directly.

## Open questions (resolve in brainstorming)

1. **Emit sink:** where do a cron turn's AG-UI events go? Nowhere (fire-and-forget), a log, or persisted so the user sees the result next time they open the chat? (Ties directly to the Flutter rebuild's "Goose owns history / bounded replay" model — a cron turn's output must be replayable via `GET .../events`.)
2. **`session_mode: new`:** still create a fresh `chats` record per fire? Who owns/sees it? Does an unattended new chat per cron fire make sense in the new model, or should cron always target an existing chat?
3. **`schedule_task` / `resolveHumanUser`:** is the whole `sessionID`-keyed API still needed, or does the rewire simplify it now that jobs carry `user`+`chat`? What was `sessionID` even resolving for?
4. **Concurrency/reservation:** the live path *reserves* the chat (`RunReserved`). What happens if a cron job fires while a user run is active on the same chat — queue, skip, error? What does `last_status` record?
5. **Auth context:** a fired job has no request auth. Confirm the coordinator path doesn't need a request-scoped auth record, or synthesize one from the job's `user`.
6. **`agent`/`poco_config` relations:** do these still select anything now that Goose provider/model is process-global env config? Likely blocked on the agent-def revamp — decide whether cron ignores them for now.

## Non-goals

- Redefining the `cron_jobs` schema (reuse it; maybe drop dead fields later).
- The agent-definition revamp (cron consumes whatever agent config exists).
- A cron *UI* in Flutter.

## Next step

Full `superpowers:brainstorming` pass, then `writing-plans`. Coordinate Q1/Q2 with the Flutter rebuild's history model.
