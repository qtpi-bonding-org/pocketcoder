# Flutter AG-UI Rebuild — Design Spec

**Date:** 2026-07-20
**Status:** DESIGN v2 — approved in brainstorming; **incorporates an independent Opus review of the connection plan** (2026-07-20) that found the original v1 seq-keyed durable-cache model unsound and led to the revised cache architecture below. Pending a final user read before an implementation plan is written. Do NOT execute from this document yet.
**Grounded against:** `services/pocketbase/internal/api/agent.go` and `internal/agent/{coordinator,agui}` (live route + bridge surface, verified 2026-07-19 acceptance suite 9/9), the c1↔Flutter contract (`2026-07-19-c1-flutter-contract-spec.md`, satisfied by c1), `coder/acp-go-sdk@v0.13.5`, `ag-ui-protocol/ag-ui` Go SDK (`@v0.0.0-20260716182252`), and the current Flutter package `client/packages/pocketcoder_flutter`.

---

## 1. Why this exists

The backend was rebuilt around a 3-container architecture (c1 = PocketBase/Go, c2 = Goose over ACP, c3 = dormant gateway). c1 exposes an **AG-UI-over-SSE down-channel** plus an **ACP-shaped REST up-channel**, and treats **Goose as the sole system of record** for turn history. The current Flutter client still speaks the *old* surface: it reads history from a Drift mirror of the deleted `messages` collection (the "cold pipe"), streams turns over `pb.realtime` (the "hot pipe"), and does HITL over the deleted `permissions` collection. Against the new backend the client is broken. This project re-points it at the AG-UI/ACP surface.

The backend down/up surface is already built and live-verified; this is a client rebuild plus a small set of backend correctness fixes (§8).

## 2. Goal

Re-point the Flutter client at c1's AG-UI/ACP surface, implementing the **full contract in v1** — prompt, streaming (text/reasoning/tool-calls), cancel, permission HITL, modes switcher, config picker, and elicitation forms — reusing the canonical protocol SDKs at every interface so no protocol schema is hand-mirrored, with **Goose as the sole authority for history** and the local cache as a Goose-refreshed offline mirror.

## 3. Governing principle: reuse the protocols at the interfaces

Every wire surface has a canonical, machine-defined schema; we consume it from an SDK rather than re-describing it. Three surfaces, three sources of truth:

| Wire surface | Source of truth | How Flutter gets the types |
|---|---|---|
| **Down-channel** — AG-UI events (`RUN_*`, `TEXT_MESSAGE_*`, `REASONING_*`, `TOOL_CALL_*`, `STATE_SNAPSHOT`/`STATE_DELTA`) | AG-UI protocol; c1 emits via the AG-UI **Go** SDK | **`ag_ui` Dart SDK** (`ag_ui.events` / `ag_ui.types` / `ag_ui.encoder`) |
| **Up-channel** — REST bodies = verbatim ACP payloads minus `sessionId`, **and** the ACP-shaped values inside `/pocketcoder/*` state deltas | ACP protocol; c1 consumes via `coder/acp-go-sdk` | **`acp_dart` SDK** (types only, `json_serializable`) |
| **PocketBase collections** (`chats`, auth, config…) | PB collection schema | **Out of scope** — see §9 |

The only Dart we author for the protocols is composition glue. The single anticipated exception is the elicitation response DTO (`acp_dart` does not ship it — §6.2, resolved in review).

### 3.1 Why not the python model pipeline for the up-channel
`generate_models.py`'s only input is `assets/pb_schema.json` (PocketBase collections). The up-channel bodies and `/pocketcoder/*` values are transient ACP-shaped shapes in c1's Go code, never persisted, so they can never appear in `pb_schema.json`. Their canonical generator is an ACP SDK (`acp_dart`), not the PB pipeline.

## 4. History authority & the cache model (revised after review)

**Goose is the sole authority for conversation history.** c1 does **not** persist an event log; the only durable anchor is the existing **`goose_sessions`** row (`chat → goose_session_id`), created on first prompt. c1's run hub is an in-memory, per-process live buffer + fan-out; durable history is obtained by replaying the Goose session (`session/load` → AG-UI) on demand.

The Flutter cache is therefore **an offline-display mirror, not an authoritative incremental log.** It exists so a chat renders instantly and works offline — never as a system of record. Its contents are always subordinate to what Goose replays.

**Two reconnect modes:**
- **Warm resume** — c1 still holds the run in memory and the client's cursor is valid → c1 sends only events with `seq > cursor` (in-memory backlog) then live-tails. The client **appends**. `seq` is a within-connection cursor; that is its only role.
- **Cold replay → replace** — the run was evicted (linger expired), or c1 restarted, or another device / a never-run chat is opening → c1 replays the whole Goose history. The client **replaces** that chat's cached view with the replayed history. Goose wins, by definition.

The client distinguishes the two by an explicit **replay marker** c1 emits at the start of a cold replay (§8.3) — not by inspecting seq values. This is the standard "full snapshot, then deltas" pattern and it removes the entire class of seq-identity problems the v1 design had (there is nothing to *match*; a cold replay is authoritative and replaces).

### 4.1 What this deliberately gives up
Reopening an evicted/old chat, opening it on a second device, or opening it after a c1 restart triggers a **cold replay and a re-render** from Goose. Offline, the stale cached view shows until the next successful replay. This is the accepted cost of not duplicating conversation content in c1; it matches the "Goose is source of truth / keep it simple" architecture.

## 5. Connection plan

### 5.1 Opening & resuming the stream
- One SSE connection per open chat: `GET /api/pocketcoder/chats/{chatId}/stream?cursor=<n>`, `Authorization: <PB token>` from the existing auth store.
- **Reconnect is driven explicitly by the client**, not by transport magic: on any drop the client reconnects with `?cursor=<MAX(seq) it has this session>`. We do **not** rely on `flutter_client_sse` auto-resending `Last-Event-ID` (unverified package behavior; review SHOULD-FIX 6). `flutter_client_sse` owns only byte transport and `: ping` heartbeat skipping.
- Each frame is `id: <seq>\n data: <json>\n\n` (c1 emits `id:` — confirmed `sse_frame.go`, and newline-escapes `data` so each event is one line). We take `seq` from `id:` and hand `data` to `ag_ui`'s `EventDecoder`. **No hand JSON parsing of events.**

### 5.2 Replay-vs-append handling
- On the **replay marker** (§8.3): clear the chat's in-memory reduced view + cache rows, then ingest the replayed events as the new baseline. `MAX(seq)` resets to the replay's last seq for subsequent warm resume.
- Otherwise (warm): upsert incoming events by `seq` and append to the reduced view.
- `seq` is treated as a live-connection cursor only; it is never assumed stable across a cold replay or a c1 restart. The cache is keyed by `(chatId, seq)` **within the current connection epoch**; a replay marker starts a fresh epoch by replacing.

### 5.3 Sending actions (up-channel)
`AgentActionsApi` builds an `acp_dart` request, `.toJson()`, strips `sessionId` (c1 injects from the path), POSTs. Returns `202`; the effect appears on the stream. Bodies (all = ACP payload − `sessionId`):
- `session/prompt` ← `PromptRequest` (ACP `ContentBlock[]`; v1 sends one text block). Returns `{runId}`. `409` if a run is active.
- `session/cancel` ← `{}`.
- `session/set_mode` ← `SetSessionModeRequest{modeId}`.
- `session/set_config_option` ← `SetSessionConfigOptionRequest` (boolean | select union).
- `session/request_permission/{requestId}` ← `RequestPermissionResponse` (`{outcome:{outcome:"selected",optionId}}` | `{outcome:{outcome:"cancelled"}}`).
- `session/elicitation/{elicitationId}` ← elicitation response (`accept{content}` | `decline` | `cancel`) — the one hand-authored DTO (§6.2).

### 5.4 Ambient session state (`/pocketcoder/*`) — all namespaces
c1's bridge emits **eight** state namespaces (verified `internal/agent/agui/bridge.go`), not the four the v1 spec named (review SHOULD-FIX 4). The reducer must handle every one it means to surface and explicitly ignore the rest:

| namespace | v1 handling |
|---|---|
| `permission` | HITL prompt (respond via up-channel) |
| `elicitation` | HITL form (respond via up-channel) |
| `modes` | mode switcher |
| `config` | config picker |
| `plan` | **surface** — todo/plan panel (user-visible) |
| `session_info` | **surface** — chat title (resolves §13 Q4) |
| `commands` | v1: ignore (documented) |
| `usage` | v1: ignore (documented) |
| `permission` cleared via `op:"remove"` | drop the affordance |

`ag_ui` provides a JSON-Patch (RFC 6902) `applyJsonPatch(state, delta)` **helper**; it does **not** maintain a materialized state object (review correction). The reducer owns the `/pocketcoder/*` map, applies `STATE_DELTA` patches (cloning — the helper mutates in place) and resets a subtree on `STATE_SNAPSHOT`, then hydrates **`acp_dart`-typed** domain values from the subtrees.

### 5.5 What we deliberately do NOT use from the SDKs
- `ag_ui` `AgUiClient` / `runAgent` / `SimpleRunAgentInput` (assumes a standard `/run` up-channel) — we use only its event models + `EventDecoder`.
- `acp_dart` `ClientSideConnection` / `AgentSideConnection` / stdio transport — we use only its types for serialization (standalone `toJson`; §13 Q1 spike to confirm).

## 6. Components & interfaces

### 6.1 Transport — `infrastructure/agent/`
- `AgentStreamClient` — `Stream<(int seq, AguiEvent)> connect(String chatId, {int cursor})`; wraps `flutter_client_sse`, decodes via `ag_ui`; surfaces the replay marker and connection loss so the repository can replace-or-append and reconnect from `MAX(seq)`.
- `AgentActionsApi` — one method per up-endpoint (§5.3), taking `acp_dart` types, mapping HTTP status → typed failures (§10).

### 6.2 Domain — `domain/agent/`
- **Events:** re-exported `ag_ui` types. **Up-channel + ambient values:** re-exported `acp_dart` types. **One exception:** `ElicitationResponse` DTO authored locally (review confirmed `acp_dart` ships no elicitation type), guarded by the contract test.
- `ConversationReducer` — pure `List<AguiEvent> → Conversation` (ordered messages: text, reasoning, tool-calls with args+result) `+ SessionState` (the surfaced `/pocketcoder/*` namespaces). No I/O.

### 6.3 Persistence — `infrastructure/agent/cache/`
Drift table `chat_events(chatId TEXT, seq INT, type TEXT, json TEXT, PRIMARY KEY(chatId, seq))`, scoped per connection epoch: a replay marker clears the chat's rows before ingesting the new baseline. Raw event JSON (not normalized columns) → zero schema migration for new event/tool types. Reactive `watch(chatId) ORDER BY seq` drives the reducer. **The cache is an offline mirror (§4), not authoritative.**

### 6.4 Application — `application/`
- `ChatCubit` — watches the cache → reduces → `ChatState`; owns the stream lifecycle (connect, explicit reconnect from `MAX(seq)`, replace-on-replay-marker, close on leave); `sendPrompt`, `cancel`.
- `PermissionCubit` / `ElicitationCubit` / `SessionControlsCubit` (modes + config) — read their `SessionState` slice, respond via `AgentActionsApi`.

### 6.5 Presentation — `presentation/`
`chat_screen` (messages + tool cards + cancel + plan panel + title), `permission_prompt`, new `elicitation_form` (renders `requestedSchema`), `mode_switcher`, `config_picker`.

## 7. Cache semantics — restated

1. **Goose is authority.** The cache never overrides a replay; a cold replay replaces it wholesale.
2. **Warm resume appends** by `seq` (within-connection cursor); **cold replay replaces** (driven by the §8.3 marker). No cross-connection/cross-restart seq matching is attempted — the design that required it (v1) was refuted by review.
3. Offline shows the last cached reduced view; it is refreshed on the next successful replay.

## 8. Backend work (pre-requisite tasks)

### 8.1 Up-channel ACP conformance fix (from v1, unchanged)
So `acp_dart` types drop in verbatim, c1 must accept true ACP bodies. Audit of `agent.go` (confirmed by review):
- **Already conformant:** `session/cancel` (`{}`), `session/set_mode` (`{modeId}`), `session/set_config_option` (binds `acpsdk.SetSessionConfigOptionRequest`).
- **Re-align:** (1) `session/prompt` accept `PromptRequest.prompt: ContentBlock[]` (read first text block; forward-compatible with richer blocks); (2) `session/request_permission/{id}` accept `RequestPermissionResponse{outcome:{outcome,optionId}}`, coordinator unwraps `outcome.optionId`; (3) `session/elicitation/{id}` accept ACP's `action` field (currently `outcome`).

### 8.2 Seq correctness (from review — required regardless of cache model)
The cold-replay path uses a **separate** seq counter (`run.go:469-472`, `seq := 0; seq++`) independent of the hub's live counter (`hub.go:59`, `h.seq++`), so a single persistent stream can emit `id:1..N` (replay) then `id:1..M` (live) — non-monotonic ids, which breaks even within-session `Last-Event-ID` resume. **Fix:** cold replay and live must draw from one monotonic per-connection counter so a stream's `id:`s are strictly increasing.

### 8.3 Replay marker (from review — the one new wire signal)
c1 must emit a distinguishable **"cold replay starting → replace"** marker at the head of a `StreamColdReplay` so the client rebuilds rather than appends (§5.2). Also fix the borrowed-cursor frames: `STATE_SNAPSHOT` and the two cold-replay `RUN_ERROR` fallbacks are written with `seq = cursor` (`agent.go:114,120,124`) — give them real monotonic seqs, or mark `STATE_SNAPSHOT` as apply-don't-persist on the client.

### 8.4 Live `modes` delta preserves `availableModes` (from review SHOULD-FIX 5)
A `CurrentModeUpdate` does `set("modes", {currentModeId})` (`bridge.go:90`), which emits `op:"add"` replacing the whole `/pocketcoder/modes` subtree (`state.go`), wiping `availableModes` until the next snapshot. **Fix:** emit a `currentModeId`-only patch (or have the reducer merge rather than trust the subtree). The `mode_switcher` depends on this.

The existing c1 acceptance suite must stay 9/9 after all of §8.

## 9. Out of scope / deferred

- **PocketBase collections & the model pipeline — untouched.** No `export_schema.sh`, no `generate_models.py` run, no deletion of `message`/`permission`/`acp_terminal` models. The client keeps its current `chats`/auth/config access as-is. Old `chat_repository`/`hitl` transport code is replaced and left dead-but-present; models are not regenerated here. A separate effort decides the collection future.
- **`session/fork`** — `acp_dart` supports it; creates a chat, belongs with chat-creation orchestration. Fast-follow.
- **Rich prompt content (image/audio/resource)** — `PromptRequest` admits them; v1 sends text only.
- **`fs/*`, `terminal/*`, `document/*`, `nes/*`** — c1 answers `unsupported` by architecture; activity reaches Flutter as tool-call events. N/A.
- **`commands`, `usage` state namespaces** — parsed-past, not surfaced in v1.

## 10. Error handling
- **Up (HTTP):** `202` · `400` malformed/option-not-offered · `401` · `404` chat/unknown-request/not-owner · `409` run-active · `503` agent-not-configured → typed failures.
- **Down (stream):** `RUN_ERROR{code}` (`goose_unavailable`, `goose_replay_failed`, +bridge codes) rendered inline, non-fatal. Cold-path `RUN_ERROR`s must carry real seqs (§8.3).
- **Transport:** SSE drop → client reconnects explicitly with `?cursor=MAX(seq)`; transient "reconnecting" state; cached view never lost.

## 11. Testing strategy
- **`ConversationReducer` unit tests** (highest value, pure): interleaved tool-calls/reasoning/text; permission add+remove; mode/config deltas; **`modes` delta must not drop `availableModes`** (§8.4); all surfaced namespaces (`plan`, `session_info`); **replay-marker → replace** semantics (a cold replay wipes and rebuilds).
- **Contract / golden parity tests** (the SDK safety net): down — decode **real captured c1 frames** (2026-07-19 acceptance run) through `ag_ui`; up — serialize each `acp_dart` body (+ the elicitation DTO) and assert it matches what c1 accepts, pinning the §8.1 re-alignment.
- **`AgentStreamClient`** — frame parsing; explicit `?cursor=MAX` reconnect (not `Last-Event-ID` reliance); replay-marker surfacing; against a fake stream.
- **Cubits** — fake repository; state transitions; actions call the API without mutating local state directly.
- **Version pinning** — `ag_ui` and `acp_dart` pinned; upgrading either re-runs the parity tests as the gate.

## 12. Security invariants (client side)
- Flutter addresses everything by `chatId`; never sees or sends `goose_session_id`.
- Flutter never holds the Goose secret or ACP URL.
- Only credential sent is the user's PB auth token, on the same c1 endpoints it already uses.

## 13. Open questions (for final review)
1. **`acp_dart` standalone types** — confirm request/response types `.toJson()` without instantiating `ClientSideConnection` (§5.5). 5-minute spike; low risk (json_serializable data classes).
2. ~~Elicitation type in `acp_dart`~~ — **RESOLVED (review): absent.** The one hand-authored DTO applies (§6.2).
3. **ACP field-naming skew** — c1 binds `acpsdk.SetSessionConfigOptionRequest` and checks `Boolean`/`ValueId` (`agent.go:199`); the `acp_dart` type must match `coder/acp-go-sdk@v0.13.5` field naming, not the contract prose. Pin via the up-parity test. Capture the golden corpus from a live run on the pinned Goose image.
4. ~~Session title source~~ — **RESOLVED (review): from `/pocketcoder/session_info` state** (`bridge.go`), surfaced by the reducer (§5.4).

---

**Next:** final user read of this v2, then `writing-plans` → implementation plan. Task ordering: **§8 backend fixes first** (up-channel ACP conformance, seq correctness, replay marker, modes-delta) with the c1 acceptance suite staying 9/9 — then the Flutter client (transport → cache → reducer → cubits → UI), reducer + parity tests leading each slice.
