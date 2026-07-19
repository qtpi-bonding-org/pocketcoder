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

**Sequencing (chat-global seq).** Each event published to a chat's hub gets a **chat-global monotonic `seq`** — it does **not** reset per run. Successive runs continue the same counter (run 1 ends at, say, `seq=40`; run 2's first event is `seq=41`). `seq` is emitted as the SSE `id:` (the writer must add `id:`, currently absent). A chat-global seq makes the stream cursor **totally ordered across runs**, so a subscriber holding `cursor=40` from run 1 that reconnects during run 2 correctly replays 41…live with no gap and no ambiguity. *(Rationale: a per-run `seq` restarting at 1 would make `cursor=40` look "ahead of" run 2's `seq=15` log and silently skip run 2's first 15 events — the C2 bug. The chat-global counter closes it.)* The `runId` returned by `prompt` (§5) identifies the run for cancel/status; the **cursor is the seq**, not the runId.

**Atomic attach — backlog is subscriber-owned, only *live* delivery can drop (keystone-safe).** Attaching must not conflate the (possibly large) backlog with the bounded live channel, or a late-joiner to a 500-event run would overflow its channel under the lock and drop-loop forever (the C1 bug). The attach protocol is:

1. **Under a single hub-lock hold:** capture a **snapshot backlog** into a *subscriber-owned buffer* (a slice, unbounded for this subscriber) = `Bridge.Snapshot()` (see below) followed by the current/lingering run's log events with `seq > cursor`; **then** register the subscriber's live bounded channel; **then** release the lock. Because registration and backlog-capture are atomic, every event that lands on the live channel afterward carries a strictly higher `seq` than everything in the buffer — ordering holds with no gap and no dup.
2. **Outside the lock**, the subscriber's SSE goroutine first flushes the buffer slice to the client, **then** switches to draining the live bounded channel.
3. **Only the live channel is subject to drop-on-full.** The backlog buffer is never dropped (it's a plain slice the SSE goroutine owns); a subscriber too slow to drain even the backlog just disconnects normally and reconnects with its last cursor.

Cold-open / evicted path: if `cursor` is older than the log's base (evicted) or there's no buffered run for the chat → the backlog is instead a **Goose bounded history replay** (`session/load` → AG-UI via the Bridge), produced into the subscriber buffer. This is the heavier path and is produced **outside** the hub lock (the lock only guards the registration + in-memory log copy).

**`Bridge.Snapshot()` shape (pinned — cross-cutting with the translation unit).** Snapshot MUST produce **one** `STATE_SNAPSHOT` whose `snapshot` payload is the **merged** `{pocketcoder:{modes,config,plan,permission,elicitation,commands,usage,session_info}}` object — **not** one `STATE_SNAPSHOT` per namespace. AG-UI's `StateSnapshotEvent` carries a single whole-state field and **replaces** the client's entire state on receipt; emitting one per namespace would leave the client holding only the last namespace's subtree and wipe the rest (the C3 bug). *This constrains the sibling Robust ACP→AG-UI Translation unit's `Snapshot()` — its plan must pin `Snapshot()` to a single merged snapshot (or an equivalent ordered set of `STATE_DELTA` add-ops that build the full tree). Flag this to the translation impl before it finalizes `Snapshot()`.*

**Never block the run (keystone).** Publishing a live event pushes to each subscriber's **bounded** channel **non-blocking**. A subscriber whose channel is full is **dropped** (channel closed → its SSE handler returns); the client reconnects with its last `cursor` and replays. The run's authoritative log write (append + seq increment) happens under the hub lock and never waits on a subscriber; the per-subscriber sends are in-memory channel ops, so holding the lock across the O(N-subscribers) fan-out is bounded and non-blocking.

**Bounded memory.** The authoritative log holds **the current run's** events (bounded by that run's length; the chat-global seq counter is just an int, it doesn't retain evicted events). A pathological single turn can still grow one run's log without cap — so the run enforces a **per-run event cap** (configurable, e.g. 50k events); exceeding it ends the run with `RUN_ERROR(run_too_large)`. On `RUN_FINISHED`, the run **lingers** in the hub for a grace window (default 30s, configurable) so tail-reconnects resume; then the log is evicted. Post-eviction reconnects fall back to Goose replay.

**Deterministic timers (test seam).** The linger window and the max-run/per-run timers MUST be driven through an injectable `Clock`/timer-factory seam (not bare `time.AfterFunc`/`time.Sleep`), and the hub exposes test-only `evictNow()`/`expireNow()` hooks, so §12's linger/eviction/timeout tests are deterministic rather than sleep-based.

**Hub teardown.** A ChatHub with no subscribers **and** no active/lingering run is removed. No orphan goroutines: the run's producer goroutine exits on turn completion/cancel; subscriber goroutines exit on client disconnect or drop. Teardown is idempotent (§5).

**Multi-subscriber.** N concurrent subscribers per chat (multi-device) each get independent cursor-based replay + live tail off the same log.

### 4a. Build vs. buy — the hub is in-house

Evaluated `tmaxmax/go-sse` (best fit: topic pub/sub, `FiniteReplayer` bounded replay by `Last-Event-ID`, custom ids, actively maintained) and `r3labs/sse` (older, `ServeHTTP`-only). **Decision: build a thin in-house hub; do not adopt a library as the hub owner.** Rationale:

1. The **keystone backpressure policy** (drop slow subscriber, never block the run) is undocumented in both libraries — it's the one behavior we cannot inherit blindly.
2. Our replay semantics are **bespoke**: per-run `seq`, linger-then-evict, `Snapshot()` injection of ambient `/pocketcoder/*` STATE on join, and Goose cold-replay fallback. A generic finite replayer covers ~half.
3. The concurrency core (bounded per-subscriber channel, non-blocking publish, drop-on-full, atomic attach, per-run log) is ~150–250 lines and is the **most test-critical, most deterministically-testable** part of the project.

**Verified backpressure fact (Opus review, from go-sse source):** the `Joe` provider **sends synchronously** — a subscriber whose callback blocks stalls `Publish` and every other subscriber; Joe removes a subscriber only on a `Send` *error*, never for merely being *slow*. So the library does **not** provide the keystone; we would write the bounded-channel, non-blocking, drop-on-full delivery ourselves regardless. That is decisive.

**Detached-run lifecycle** has no library candidate at all — it's stdlib `context`/goroutines/timers (+ maybe `golang.org/x/sync`). SSE framing (`id:`/`data:` + flush) is ~20 lines and the writer needs an `id:` line added anyway, so we **skip go-sse even for framing** — a dependency for 20 lines is negative value. Keep its `FiniteReplayer` as a **reference pattern** only. The hub is fully in-house.

## 5. Detached run lifecycle

- **Start:** `Reserve(chatID)` (one run per chat) → spawn the run on a **`context.Background()`-derived** ctx owned by the run, **not** the request. This same run ctx MUST be the ctx passed to the Goose WS `Dial` (the ACP read/write loop is bound to the dial ctx, `acp/websocket.go:107`) — dialing with the request ctx would kill the WS on client disconnect, reintroducing the exact bug this design removes. `POST …/session/prompt` returns **202 `{runId}`** immediately; it does not stream.
- **Produce:** the ACP `sessionClient` callbacks call `Bridge.Update(...)`; results are published to the ChatHub (§4). This replaces today's direct-to-`emit`.
- **Finish:** on ACP `PromptResponse`, append `RUN_FINISHED` carrying the mapped `stopReason` (SDK `StopReason` = `end_turn`/`cancelled`/`refusal`/`max_tokens`/`max_turn_requests`) — so the consumed `Bridge.Finished(stopReason)` reports a **non-success** outcome for non-`end_turn` stops instead of hardcoding success (today `Finished()` is arg-less and always `WithSuccessOutcome`, `bridge.go:135`). Then enter linger, release `Reserve`, tear down the ACP conn. *(This pins the sibling translation unit's `Finished` to accept a `stopReason`.)*
- **Idempotent teardown (`sync.Once`).** Detached runs have multiple teardown triggers that can fire concurrently (finish, cancel, permission/elicitation timeout, max-run timeout, shutdown, per-run cap). Teardown is guarded by a `sync.Once` and, in order: (1) atomically flip the run's `accepting` flag **false** and detach the hub's active-run pointer, so a straggler `SessionUpdate` can never publish into the *next* run's log; (2) stop **all** run timers (permission, elicitation, max-run) — an un-stopped `AfterFunc` otherwise pins the run/conn closure and can fire post-teardown; (3) close the ACP conn once; (4) drop pending permission/elicitation for the chat; (5) release `Reserve`. Release is **last**, so a new run cannot reuse the hub while stragglers are in flight.
- **Panic safety.** The run goroutine `defer`s a `recover()` that emits `RUN_ERROR(protocol_error)` and runs teardown (releasing `Reserve`). Without this, a panic in produce/teardown leaks the in-memory `Reserve` and wedges the chat at `409` until c1 restart.
- **Cancel triggers (disconnect is NOT one):**
  - explicit `POST …/session/cancel`;
  - permission timeout (exists) / elicitation timeout (new, §8);
  - **new max-run timeout** (safety for a wedged headless run) — configurable, e.g. 15 min;
  - per-run event cap exceeded (§4) → `RUN_ERROR(run_too_large)`;
  - coordinator `Shutdown` (exists).
- **`Reserve` decoupled from streaming.** `Reserve` guards **prompt-start only**. `GET …/stream` subscribes **without** reserving (today's `events` wrongly reserves and 409s). A run and its subscribers coexist. Reserve is released in teardown, **after** `RUN_FINISHED` is appended and the hub's active-run pointer is detached — so the window between "finish appended" and "Reserve free" cannot admit a second prompt that races the still-lingering log; a 2nd prompt during that window either 409s (Reserve still held) or starts cleanly (Reserve freed, new run, continuing chat-global seq).

## 6. Goose connection lifecycle

- **Dial-per-run**, connection **owned by the run** (not the request, N1 above) so it survives client disconnect. Isolated failure domain per run; simplest correct model.
- **`initialize` must advertise `ClientCapabilities.Elicitation`** (currently empty, `run.go:259`), or Goose will never send elicitations and §8's handler is dead code.
- **Init sequence per run:** `initialize` → `session/new` (lazy, first prompt; persist `goose_sessions` map) or `session/load` → seed `/pocketcoder/modes` + `/pocketcoder/config` from the response into the Bridge → `set_mode` (default or client-chosen) → `Started()` → `prompt`.
- **Orphaned-session compensation (S4).** `session/new` creates a **durable** Goose session; if the subsequent `goose_sessions` mapping-persist fails, the session exists but is unmapped → the next prompt would `session/new` again and strand the first turn's history. On persist failure the run MUST compensate: `session/delete` the just-created session before erroring, so no orphan is left. *(Symmetric to §9's delete path.)*
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

- **Elicitation (Unstable ACP):** the client must additionally implement `UnstableCreateElicitation` — the SDK dispatches elicitation by type-asserting the client (`client_gen.go:37`), so it is **not** satisfied by the base `Client` interface the current struct implements (S7). The handler surfaces the request via the Bridge as `/pocketcoder/elicitation` state, blocks the ACP request on a `pendingElicitation` channel (mirroring `pendingPermission`), and resolves on `POST …/session/elicitation/{id}` (accept/decline/cancel) or an **explicit elicitation timeout** (configurable, mirror the permission `5m`; on timeout resolve `cancelled`). Permission-id and elicitation-id keyspaces must not collide in coordinator state (keep them in separate maps, N5). With detached runs a permission/elicitation can fire with **zero** attached subscribers; that is bounded by its own timeout (well under max-run) and its pending state is in `Snapshot()` (§4) so a late-joiner can still resolve it. Gate on the pinned Goose image actually emitting it.
- **set_mode / set_config_option:** dispatch to the ACP methods; the resulting `CurrentModeUpdate`/`ConfigOptionUpdate` from Goose flow back through the Bridge to update state (closed loop).
- **Modes/config surfacing:** feed `NewSession`/`LoadSession` response `Modes`/`ConfigOptions` into the Bridge on run init (§6).

## 9. Session lifecycle orchestration (c1-owned)

- **new** — lazy on first prompt (exists; keep).
- **load** — on cold-open replay / run init (exists; keep).
- **delete** — hook `chats` record delete → `session/delete` on Goose + remove `goose_sessions` map. This fires from a PocketBase record hook where there is **no active run or SSE stream** to carry a `RUN_ERROR`, so "loud" is defined concretely (S5): the `session/delete` runs in the **`OnRecordAfterDeleteSuccess`-adjacent** path and, on Goose rejection, does **not** silently swallow — it logs at error and records the orphan for a reconcile sweep (a startup/periodic pass that retries `session/delete` for `goose_sessions` rows whose `chats` parent is gone). We do **not** block the user's chat delete on Goose availability (Goose may be down); we guarantee eventual cleanup instead. Add `session_delete_failed` to the §10 taxonomy for the logged/reconcile surface. The `Conn` interface must expose `UnstableDeleteSession` (SDK `client_gen.go:271`), not currently in `acp.Conn`.
- **close** — **deferred** (Goose owns session persistence; revisit under resource pressure).
- **fork** — **deferred to fast-follow** (Unstable ACP; needs new-chat orchestration). Not v1.

## 10. Error taxonomy

- **HTTP:** `202` / `400` / `401` / `404` / `409 run active` / `503 not configured` (per contract §7).
- **`RUN_ERROR` codes:** `goose_unavailable` (dial/turn/WS failure), `goose_replay_failed` (history replay), `session_load_failed`, `protocol_error` (fatal translation/ACP error, incl. panic-recover), `run_timeout` (max-run cap), `run_too_large` (per-run event cap, §4). Soft translation misses are `RAW`, not `RUN_ERROR` (translation spec §5.2).
- **Non-run surfaces:** `session_delete_failed` (§9 — logged + reconcile sweep, not carried on a stream since delete has no active run).

## 11. Decisions taken (robust defaults — veto on review)

1. Slow subscriber → **drop + reconnect-with-cursor**, never block/unbounded-buffer. *(keystone)*
2. Last subscriber leaving does **not** cancel a run; only explicit cancel / max-run timeout / shutdown.
3. `Reserve` guards **prompt-start only**; `stream` doesn't reserve.
4. **Dial-per-run**, connection owned by the run; pooled connection deferred.
5. Mid-turn Goose WS failure → `RUN_ERROR`, **no auto-resume**; c1-restart durability out of scope.
6. `session/close` deferred; `fork` deferred to fast-follow.
7. Linger window 30s; max-run timeout ~15m; elicitation timeout ~5m; per-run event cap ~50k; all configurable (env). Timers/linger go through an injectable clock seam for deterministic tests (§4, §12).
8. **Hub built fully in-house** — no `tmaxmax/go-sse` (its `Joe` provider sends synchronously → can't satisfy the drop-slow keystone; framing is ~20 lines) (§4a).
9. **`seq` is chat-global monotonic**, not per-run-from-1; the stream cursor is the `seq` (totally ordered across runs), and the `runId` from `prompt` identifies the run for cancel/status only (§4, resolves review C2).
10. **Backlog is subscriber-owned (unbounded slice); only live delivery is drop-on-full** — attach captures backlog + merged `Snapshot()` under the lock, flushes outside it, then joins the live bounded channel (§4, resolves review C1).
11. **`Snapshot()` is one merged `STATE_SNAPSHOT`** over all `/pocketcoder/*` namespaces, never one-per-namespace (AG-UI snapshot replaces whole state) — pins the sibling translation unit (§4, resolves review C3).
12. **Teardown is `sync.Once`-idempotent**; `Reserve` released last; run goroutine `recover()`s and releases on panic (§5, resolves review S2/S3/S8).

## 12. Testing strategy (TDD)

- **Hub unit tests (deterministic via the clock seam, no Goose):** atomic attach (no gap/dup across backlog→live, incl. a backlog **larger than the live channel cap** — must NOT drop, proving C1's subscriber-owned buffer); **chat-global seq continuity** across two runs (cursor from run 1 resumes into run 2 with no skipped events, proving C2); merged single `STATE_SNAPSHOT` on join (proving C3); multi-subscriber fan-out; **slow-subscriber drop** (full *live* channel → closed, run unaffected); cursor resume after drop; linger window and eviction driven by `evictNow()` (tail reconnect vs post-eviction Goose-replay fallback); teardown leaves no goroutine/hub.
- **Run lifecycle tests:** disconnect does **not** cancel; explicit cancel does; max-run/per-run-cap fire via `expireNow()`; teardown idempotency (concurrent finish+cancel → single conn close, single Reserve release, no straggler into next run); panic in produce releases Reserve; `Reserve` blocks a 2nd prompt (409) but not a stream subscribe.
- **Method tests:** set_mode/set_config round-trip updates state; elicitation request→response→resume; permission unchanged.
- **`live_acp` integration (build-tagged, real Goose):** full authed turn over the new stream; reconnect mid-turn resumes; wrong token → 401; a real diff/tool turn renders through the translation unit.
- Existing `tests/agent-c1` wiring updated to the `prompt`+`stream` split.

## 13. Module structure

- `internal/agent/coordinator/hub.go` — ChatHub, Subscriber, chat-global seq log, subscriber-owned backlog + live bounded channel, fan-out, linger, clock seam, teardown.
- `internal/agent/coordinator/run.go` — reworked: detached run lifecycle, background ctx (also the dial ctx), `sync.Once` teardown, panic-recover, cancel triggers, publish-to-hub.
- `internal/agent/coordinator/session.go` — ACP init sequence (incl. `Elicitation` capability advertise), lifecycle (new/load/delete + orphan compensation/reconcile), modes/config seeding, elicitation handler.
- `internal/agent/coordinator/coordinator.go` — Reserve/dispatch/timers/shutdown.
- `internal/agent/acp/` — extend the `Conn` interface + client: `SetSessionConfigOption` (`client_gen.go:304`), `UnstableDeleteSession` (`client_gen.go:271`), and the `UnstableCreateElicitation` handler method (`client_gen.go:37`).
- `internal/api/agent.go` — reworked routes (prompt/stream/cancel/set_mode/set_config/permission/elicitation), SSE `id:` emission (echoing the chat-global seq), `chats` delete hook.
- Tests alongside each.

## 14. Scope boundaries

**In:** everything above. **Out (named follow-ups):** c1-restart durability, pooled Goose connection, `session/close` eviction, `session/fork`, providers/model selection (agent-def revamp), the Flutter client, cron-on-c1 (a later consumer of this bridge).

## 15. Dependencies & sequencing

1. **Robust ACP→AG-UI translation** (its own spec) — the event producer; land or co-develop first.
2. **This bridge** — consumes the translation unit, fulfills the contract.
3. Then: contract-doc catch-up (translation §9 additions), then the Flutter client.
