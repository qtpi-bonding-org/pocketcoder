# Robust c1 ↔ c2 (ACP) Bridge — Spec

**Date:** 2026-07-19
**Status:** DRAFT SPEC — ready for user review, then a plan. The foundational backend project; the c1↔Flutter contract is its acceptance target.
**Grounded against:** `internal/agent/{coordinator,acp,agui}`, `internal/api/agent.go`, `coder/acp-go-sdk@v0.13.5`, `ag-ui-protocol/ag-ui` Go SDK.
**Consumes:** the *Robust ACP→AG-UI Translation* unit (`2026-07-19-acp-agui-translation-robust-spec.md`) as its event producer.
**Fulfills:** the *c1↔Flutter Contract* (`2026-07-19-c1-flutter-contract-spec.md`) §9 gap list.

## 1. Goal — what "robust" means here

Turn today's single-turn happy-path coordinator into a durable, concurrent, fully-wired ACP bridge. "Robust" is concretely:

- **Detached:** a run's lifetime is independent of any client connection.
- **Re-attachable:** any number of subscribers can observe a run, join late, and resume after disconnect via a cursor — without ever stalling the run.
- **Complete:** every contract method (prompt, cancel, set_mode, set_config_option, permission, **elicitation**) and lifecycle path is wired; modes/config are surfaced, not discarded.
- **Non-blocking & leak-free:** slow/dead subscribers never block the agent or grow memory unbounded; every run, connection, timer, and goroutine has a defined teardown.
- **Loud & typed on failure:** a bounded `RUN_ERROR` taxonomy; no silent drops.

**Not "robust":** surviving a **c1 restart** mid-turn (in-memory hub; Goose's own persistence covers durable history via replay), or auto-resuming an in-flight prompt across a Goose WS blip. Both are explicit boundaries (§9).

## 2. Current state (why it's thin)

`coordinator.RunReserved(ctx, …)` binds the whole turn to `re.Request.Context()`, emits to **one** SSE writer, **cancels the Goose turn on client disconnect** (`run.go:325`), blocks permission on `ctx.Done()`, hardcodes `"approve"`, discards `Modes`/`ConfigOptions`, and `GET /events` `Reserve()`s so it 409s during a run. See the audit in the contract spec §9.

## 3. Architecture

```
        ┌────────────────────────── c1 (PocketBase) ──────────────────────────┐
Flutter │  REST actions ─► Coordinator ─► Run (bg ctx, owns ACP conn) ─► Goose │
  (SSE) │       ▲                │            │  produces via Bridge            │
        │       └── ChatHub ◄────┴── fan-out ─┘  (translation unit)            │
        │        (subscribers, per-run log, seq, state snapshot)               │
        └──────────────────────────────────────────────────────────────────────┘
```

New/changed components:
- **ChatHub** (new) — per-chat fan-out point: subscriber set + current run's seq'd event log + the Bridge's state projection. Persists while it has ≥1 subscriber or an active/lingering run.
- **Run** (reworked `activeRun`) — owns the ACP `Conn`, a **background** ctx+cancel, the `agui.Bridge`, and publishes events into its ChatHub. Lifetime independent of any request.
- **Subscriber** (new) — one `GET …/stream`; a bounded channel + a cursor.
- **Coordinator** — orchestrates Reserve, run start/teardown, hub lifecycle, method dispatch, timers.

## 4. The run hub — the heart (behavior + invariants)

Specified as invariants; data structures are the plan's concern.

**Sequencing.** Each event published to a run gets a **monotonic `seq` starting at 1** (per run). `seq` is emitted as the SSE `id:` (the writer must add `id:`, currently absent).

**Atomic attach (no gap/dup).** A subscriber attaching with `cursor` is registered **and** served its backlog under a single hub lock hold, so no event can slip between "replay" and "live." Backlog =
- events in the current/lingering run's log with `seq > cursor`, **plus** `Bridge.Snapshot()` (a `STATE_SNAPSHOT` per `/pocketcoder/*` namespace) so ambient state (modes, config, plan, pending permission/elicitation) is correct on join;
- if the cursor is older than the log's base (evicted) or there's no buffered run → a **Goose bounded history replay** (`session/load` → AG-UI), then live registration. (Heavier cold-open path; run outside the lock.)

**Never block the run (keystone).** Publishing pushes to each subscriber's **bounded** channel **non-blocking**. A subscriber whose channel is full is **dropped** (channel closed → its SSE handler returns); the client reconnects with its last `cursor` and replays. The run's authoritative log write never blocks and never waits on a subscriber.

**Bounded memory.** The authoritative log holds **one run's** events (bounded by that run's length). On `RUN_FINISHED`, the run **lingers** in the hub for a grace window (default 30s, configurable) so tail-reconnects resume; then the log is evicted. Post-eviction reconnects fall back to Goose replay.

**Hub teardown.** A ChatHub with no subscribers **and** no active/lingering run is removed. No orphan goroutines: the run's producer goroutine exits on turn completion/cancel; subscriber goroutines exit on client disconnect or drop.

**Multi-subscriber.** N concurrent subscribers per chat (multi-device) each get independent cursor-based replay + live tail off the same log.

### 4a. Build vs. buy — the hub is in-house

Evaluated `tmaxmax/go-sse` (best fit: topic pub/sub, `FiniteReplayer` bounded replay by `Last-Event-ID`, custom ids, actively maintained) and `r3labs/sse` (older, `ServeHTTP`-only). **Decision: build a thin in-house hub; do not adopt a library as the hub owner.** Rationale:

1. The **keystone backpressure policy** (drop slow subscriber, never block the run) is undocumented in both libraries — it's the one behavior we cannot inherit blindly.
2. Our replay semantics are **bespoke**: per-run `seq`, linger-then-evict, `Snapshot()` injection of ambient `/pocketcoder/*` STATE on join, and Goose cold-replay fallback. A generic finite replayer covers ~half.
3. The concurrency core (bounded per-subscriber channel, non-blocking publish, drop-on-full, atomic attach, per-run log) is ~150–250 lines and is the **most test-critical, most deterministically-testable** part of the project.

**Verified backpressure fact (Opus review, from go-sse source):** the `Joe` provider **sends synchronously** — a subscriber whose callback blocks stalls `Publish` and every other subscriber; Joe removes a subscriber only on a `Send` *error*, never for merely being *slow*. So the library does **not** provide the keystone; we would write the bounded-channel, non-blocking, drop-on-full delivery ourselves regardless. That is decisive.

**Detached-run lifecycle** has no library candidate at all — it's stdlib `context`/goroutines/timers (+ maybe `golang.org/x/sync`). SSE framing (`id:`/`data:` + flush) is ~20 lines and the writer needs an `id:` line added anyway, so we **skip go-sse even for framing** — a dependency for 20 lines is negative value. Keep its `FiniteReplayer` as a **reference pattern** only. The hub is fully in-house.

## 5. Detached run lifecycle

- **Start:** `Reserve(chatID)` (one run per chat) → spawn the run on a **`context.Background()`-derived** ctx owned by the run, **not** the request. `POST …/session/prompt` returns **202 `{runId}`** immediately; it does not stream.
- **Produce:** the ACP `sessionClient` callbacks call `Bridge.Update(...)`; results are published to the ChatHub (§4). This replaces today's direct-to-`emit`.
- **Finish:** on ACP `PromptResponse`, append `RUN_FINISHED` (mapping `stopReason`), enter linger, release `Reserve`, tear down the ACP conn.
- **Cancel triggers (disconnect is NOT one):**
  - explicit `POST …/session/cancel`;
  - permission timeout (exists);
  - **new max-run timeout** (safety for a wedged headless run) — configurable, e.g. 15 min;
  - coordinator `Shutdown` (exists).
- **`Reserve` decoupled from streaming.** `Reserve` guards **prompt-start only**. `GET …/stream` subscribes **without** reserving (today's `events` wrongly reserves and 409s). A run and its subscribers coexist.

## 6. Goose connection lifecycle

- **Dial-per-run**, connection **owned by the run** (not the request) so it survives client disconnect. Isolated failure domain per run; simplest correct model.
- **Init sequence per run:** `initialize` → `session/new` (lazy, first prompt; persist `goose_sessions` map) or `session/load` → seed `/pocketcoder/modes` + `/pocketcoder/config` from the response into the Bridge → `set_mode` (default or client-chosen) → `Started()` → `prompt`.
- **Mid-turn WS failure → `RUN_ERROR` (`goose_unavailable`), no auto-resume** of an in-flight prompt (documented boundary). Replay reflects whatever Goose durably persisted.
- **Pooled/persistent connection** (one WS serving many chats via ACP session multiplexing) is a **deferred optimization** — more failure-domain coupling; not needed for robust v1.

## 7. Endpoint wiring (the mechanical layer)

Implements the contract spec §6 verbatim; `sessionId` injected from `{chatId}`.

| Endpoint | ACP call | Notes |
|---|---|---|
| `GET …/stream?cursor=` | (subscribe) | persistent, cursor-resumable, no Reserve |
| `POST …/session/prompt` | `session/prompt` | 202 `{runId}`; 409 if run active |
| `POST …/session/cancel` | `session/cancel` | 202 |
| `POST …/session/set_mode` | `session/set_mode` | 202; validated against surfaced modes |
| `POST …/session/set_config_option` | `session/set_config_option` | 202 |
| `POST …/session/request_permission/{id}` | (permission response) | 202; existing `pendingPermission` path |
| `POST …/session/elicitation/{id}` | (elicitation response) | 202; new (§8) |

`POST /runs` (today's streaming action) is **removed** in favor of `prompt` + `stream`.

## 8. New capability wiring

- **Elicitation (Unstable ACP):** implement the `sessionClient` handler for `unstable/create_elicitation` — surface via the Bridge as `/pocketcoder/elicitation` state, block the ACP request on a `pendingElicitation` channel (mirroring `pendingPermission`), resolve on `POST …/session/elicitation/{id}` (accept/decline/cancel) or timeout. Gate on the pinned Goose image actually emitting it.
- **set_mode / set_config_option:** dispatch to the ACP methods; the resulting `CurrentModeUpdate`/`ConfigOptionUpdate` from Goose flow back through the Bridge to update state (closed loop).
- **Modes/config surfacing:** feed `NewSession`/`LoadSession` response `Modes`/`ConfigOptions` into the Bridge on run init (§6).

## 9. Session lifecycle orchestration (c1-owned)

- **new** — lazy on first prompt (exists; keep).
- **load** — on cold-open replay / run init (exists; keep).
- **delete** — hook `chats` record delete → `session/delete` on Goose + remove `goose_sessions` map. Loud error if Goose rejects (no silent guard).
- **close** — **deferred** (Goose owns session persistence; revisit under resource pressure).
- **fork** — **deferred to fast-follow** (Unstable ACP; needs new-chat orchestration). Not v1.

## 10. Error taxonomy

- **HTTP:** `202` / `400` / `401` / `404` / `409 run active` / `503 not configured` (per contract §7).
- **`RUN_ERROR` codes:** `goose_unavailable` (dial/turn/WS failure), `goose_replay_failed` (history replay), `session_load_failed`, `protocol_error` (fatal translation/ACP error), `run_timeout` (max-run cap). Soft translation misses are `RAW`, not `RUN_ERROR` (translation spec §5.2).

## 11. Decisions taken (robust defaults — veto on review)

1. Slow subscriber → **drop + reconnect-with-cursor**, never block/unbounded-buffer. *(keystone)*
2. Last subscriber leaving does **not** cancel a run; only explicit cancel / max-run timeout / shutdown.
3. `Reserve` guards **prompt-start only**; `stream` doesn't reserve.
4. **Dial-per-run**, connection owned by the run; pooled connection deferred.
5. Mid-turn Goose WS failure → `RUN_ERROR`, **no auto-resume**; c1-restart durability out of scope.
6. `session/close` deferred; `fork` deferred to fast-follow.
7. Linger window 30s; max-run timeout ~15m; both configurable (env).
8. **Hub built fully in-house** — no `tmaxmax/go-sse` (its `Joe` provider sends synchronously → can't satisfy the drop-slow keystone; framing is ~20 lines) (§4a).

## 12. Testing strategy (TDD)

- **Hub unit tests (deterministic, no Goose):** atomic attach (no gap/dup across replay→live); multi-subscriber fan-out; **slow-subscriber drop** (full channel → closed, run unaffected); cursor resume after drop; linger window (tail reconnect vs post-eviction Goose-replay fallback); teardown leaves no goroutine/hub.
- **Run lifecycle tests:** disconnect does **not** cancel; explicit cancel does; max-run timeout fires; `Reserve` blocks a 2nd prompt (409) but not a stream subscribe.
- **Method tests:** set_mode/set_config round-trip updates state; elicitation request→response→resume; permission unchanged.
- **`live_acp` integration (build-tagged, real Goose):** full authed turn over the new stream; reconnect mid-turn resumes; wrong token → 401; a real diff/tool turn renders through the translation unit.
- Existing `tests/agent-c1` wiring updated to the `prompt`+`stream` split.

## 13. Module structure

- `internal/agent/coordinator/hub.go` — ChatHub, Subscriber, seq log, fan-out, linger, teardown.
- `internal/agent/coordinator/run.go` — reworked: detached run lifecycle, background ctx, cancel triggers, publish-to-hub.
- `internal/agent/coordinator/session.go` — ACP init sequence, lifecycle (new/load/delete), modes/config seeding, elicitation handler.
- `internal/agent/coordinator/coordinator.go` — Reserve/dispatch/timers/shutdown.
- `internal/api/agent.go` — reworked routes (prompt/stream/cancel/set_mode/set_config/permission/elicitation), SSE `id:` emission, `chats` delete hook.
- Tests alongside each.

## 14. Scope boundaries

**In:** everything above. **Out (named follow-ups):** c1-restart durability, pooled Goose connection, `session/close` eviction, `session/fork`, providers/model selection (agent-def revamp), the Flutter client, cron-on-c1 (a later consumer of this bridge).

## 15. Dependencies & sequencing

1. **Robust ACP→AG-UI translation** (its own spec) — the event producer; land or co-develop first.
2. **This bridge** — consumes the translation unit, fulfills the contract.
3. Then: contract-doc catch-up (translation §9 additions), then the Flutter client.
