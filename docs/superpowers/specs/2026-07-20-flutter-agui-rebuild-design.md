# Flutter AG-UI Rebuild — Design Spec

**Date:** 2026-07-20
**Status:** DESIGN — approved in brainstorming; pending spec review (incl. an independent Opus review of the connection plan) before an implementation plan is written. Do NOT execute from this document yet.
**Grounded against:** `services/pocketbase/internal/api/agent.go` (live route surface, verified 2026-07-19 acceptance suite 9/9), the c1↔Flutter contract (`2026-07-19-c1-flutter-contract-spec.md`, now satisfied by c1), `coder/acp-go-sdk@v0.13.5` (c1's ACP SDK), `ag-ui-protocol/ag-ui` Go SDK (`@v0.0.0-20260716182252`, c1's emitter), and the current Flutter package `client/packages/pocketcoder_flutter`.

---

## 1. Why this exists

The backend was rebuilt around a 3-container architecture (c1 = PocketBase/Go, c2 = Goose over ACP, c3 = dormant gateway). c1 now exposes an **AG-UI-over-SSE down-channel** plus an **ACP-shaped REST up-channel**, and treats **Goose as the sole system of record** for turn history. The current Flutter client still speaks the *old* surface: it reads history from a Drift mirror of the deleted `messages` collection (the "cold pipe"), streams turns over `pb.realtime` (the "hot pipe"), and does HITL over the deleted `permissions` collection. Against the new backend the client is broken. This project re-points it at the AG-UI/ACP surface.

The backend side of the contract is **already built and live-verified**; this is a client-only rebuild plus one small backend conformance fix (§8).

## 2. Goal

Re-point the Flutter client at c1's AG-UI/ACP surface, implementing the **full contract in v1** — prompt, streaming (text/reasoning/tool-calls), cancel, permission HITL, modes switcher, config picker, and elicitation forms — with a **server-authoritative local cache**, reusing the canonical protocol SDKs at every interface so no protocol schema is hand-mirrored.

## 3. The governing principle: reuse the protocols at the interfaces

Every wire surface has a canonical, machine-defined schema. We consume that schema from an SDK rather than re-describing it by hand. There are exactly three wire surfaces and three sources of truth:

| Wire surface | Source of truth | How Flutter gets the types |
|---|---|---|
| **Down-channel** — AG-UI event envelope (`RUN_*`, `TEXT_MESSAGE_*`, `REASONING_*`, `TOOL_CALL_*`, `STATE_SNAPSHOT`/`STATE_DELTA`) | AG-UI protocol; c1 emits via the AG-UI **Go** SDK | **`ag_ui` Dart SDK** (`ag_ui.events` / `ag_ui.types` / `ag_ui.encoder`) |
| **Up-channel** — REST bodies that are verbatim ACP payloads minus `sessionId`, **and** the ACP-shaped *values* carried inside `/pocketcoder/*` state deltas | ACP protocol; c1 consumes via `coder/acp-go-sdk` | **`acp_dart` SDK** (types only, `json_serializable`) |
| **PocketBase collections** (`chats`, auth, config…) | PB collection schema | **Out of scope for this project** — see §9 |

**Consequence:** the only Dart we author for the protocols is composition glue (open the stream, feed frames to a decoder, POST a serialized body) — never the field definitions themselves. The one anticipated exception is the elicitation response type if `acp_dart` turns out not to ship it (§6.2, §8).

### 3.1 Why not the python model pipeline for the up-channel

`generate_models.py` has a single input, `assets/pb_schema.json` — the export of **PocketBase collections**. The up-channel bodies and the `/pocketcoder/*` state values are **transient request/state shapes defined in c1's Go code**, never persisted, so they can never appear in `pb_schema.json`. They are ACP-shaped, so their canonical generator is an ACP SDK (`acp_dart`), not the PB pipeline. Forcing them through PB schema would mean inventing fake collections — strictly worse.

## 4. Architecture & data flow

```
                    c1  (PocketBase / Go)
   ┌───────────────────────────────────────────────┐
   │  GET  /chats/{id}/stream?cursor=<seq>   (down)  │  AG-UI over SSE
   │  POST /chats/{id}/session/prompt        (up)    │  ACP body − sessionId
   │  POST /chats/{id}/session/cancel                │
   │  POST /chats/{id}/session/set_mode             │
   │  POST /chats/{id}/session/set_config_option     │
   │  POST /chats/{id}/session/request_permission/{r}│
   │  POST /chats/{id}/session/elicitation/{e}       │
   └───────────────────────────────────────────────┘
                    ▲ (authed: PB token)         │
                    │ REST (acp_dart bodies)     │ SSE frames (id: seq + data: json)
                    │                            ▼
   ┌────────────────┴───────────────┐   ┌───────────────────────────────┐
   │      AgentActionsApi           │   │      AgentStreamClient         │
   │  (acp_dart types → JSON POST)  │   │ flutter_client_sse GET →       │
   └────────────────────────────────┘   │ ag_ui EventDecoder → AguiEvent │
                    ▲                    └───────────────┬───────────────┘
                    │                                    │ raw event JSON + seq
                    │                                    ▼
                    │                     ┌───────────────────────────────┐
                    │                     │  Drift: chat_events            │
                    │                     │  (chatId, seq, type, json)     │  server-authoritative
                    │                     │  PK(chatId, seq)  upsert       │  cursor = MAX(seq)
                    │                     └───────────────┬───────────────┘
                    │                                     │ reactive watch (ORDER BY seq)
                    │                                     ▼
                    │                     ┌───────────────────────────────┐
                    │                     │  ConversationReducer (pure)    │
                    │                     │  events → Conversation +       │
                    │                     │  SessionState(/pocketcoder/*)  │
                    │                     └───────────────┬───────────────┘
                    │                                     ▼
   ┌────────────────┴─────────────────────────────────────────────────────┐
   │  ChatCubit · PermissionCubit · ElicitationCubit · SessionControlsCubit │
   └───────────────────────────────────────┬──────────────────────────────┘
                                            ▼
                          chat_screen + widgets (messages, tool cards,
                          permission prompt, elicitation form, mode/config)
```

**One directional rule:** the stream is the only writer into the cache; the cache is the only reader for the UI. Up-channel actions never mutate local state directly — their effect returns as events on the stream. This is what makes "server always wins" true by construction.

## 5. Connection plan (the load-bearing section)

This section is deliberately exhaustive because the whole design rests on using each protocol the way its authors intend.

### 5.1 Opening the stream

- One SSE connection per open chat: `GET /api/pocketcoder/chats/{chatId}/stream?cursor=<n>`, `Authorization: <PB token>` from the existing auth store. `n` = `MAX(seq)` currently in Drift for this chat (0 if none → full bounded replay).
- `flutter_client_sse` owns the transport: connection, the `: ping` heartbeat comments (ignored), and reconnection. On reconnect it resends `Last-Event-ID` (the last `id:` it saw) — which **is** our per-run `seq` cursor. c1 already reads `Last-Event-ID` as the cursor (`agent.go` `parseCursor`), so resume is native, no bespoke logic.
- Each received SSE frame is `id: <seq>\n data: <json>\n\n`. We take `seq` from `id:` and hand `data` to `ag_ui`'s `EventDecoder`/event factory to get a typed `AguiEvent`. **We never parse event JSON by hand.**

### 5.2 Cursor / replay semantics (mirrors c1 exactly)

c1's `Attach(cursor)` already decides replay vs live-tail (`hub.go`), including cold replay from Goose for evicted/never-run/ post-restart cases. The client's job is only to *supply the right cursor* and *persist every event it sees*:

- Cold open (nothing cached): `cursor=0` → c1 emits bounded Goose history (`RUN_STARTED … RUN_FINISHED`) then idles/live-tails. We persist all of it; `MAX(seq)` advances.
- Warm reconnect: `cursor=MAX(seq)` → c1 replays only `seq > cursor` from the run hub, else fresh history. No duplicates because `seq` is chat-global monotonic and our upsert PK is `(chatId, seq)`.
- The client treats a replayed event and a live event **identically** — both are just rows upserted by `seq`. Reduction is unaware of the distinction.

### 5.3 Sending actions (up-channel)

- `AgentActionsApi` builds an `acp_dart` request object, calls `.toJson()`, strips `sessionId` (c1 injects it from the path), and POSTs. Returns `202`; the effect appears on the stream.
- Mapping (all bodies = ACP payload − `sessionId`):
  - `session/prompt` ← `PromptRequest` (ACP `ContentBlock[]`; v1 sends a single text block, but the type admits image/resource later for free). Returns `{runId}`. `409` if a run is active.
  - `session/cancel` ← `{}` (ACP notification).
  - `session/set_mode` ← `SetSessionModeRequest{modeId}`.
  - `session/set_config_option` ← `SetSessionConfigOptionRequest` (boolean | select union).
  - `session/request_permission/{requestId}` ← `RequestPermissionResponse` (`{outcome:{outcome:"selected",optionId}}` | `{outcome:{outcome:"cancelled"}}`).
  - `session/elicitation/{elicitationId}` ← ACP elicitation response (`accept{content}` | `decline` | `cancel`).

### 5.4 Ambient session state (`/pocketcoder/*`)

- c1 mirrors four namespaces into the AG-UI state object via `STATE_SNAPSHOT` / `STATE_DELTA` (JSON-Patch RFC 6902): `permission`, `elicitation`, `modes`, `config`.
- `ag_ui` applies the JSON-Patch to a generic state map (this is a first-class SDK feature). Our reducer reads the resulting `/pocketcoder/*` subtrees and hydrates **`acp_dart`-typed** domain values (permission options, mode descriptors, config options, elicitation `requestedSchema`), because those values are ACP shapes c1 lifted out of `session/update`.
- Cleared entries arrive as `op:"remove"`; the reducer drops the corresponding UI affordance.

### 5.5 What we deliberately do NOT use from the SDKs

- **`ag_ui` `AgUiClient.runAgent()` / `SimpleRunAgentInput`** — assumes a standard AG-UI `/run` up-channel. Ours is ACP-shaped REST. We use only `ag_ui`'s **event models + decoder**, not its client. (The sub-package split makes this clean.)
- **`acp_dart` `ClientSideConnection` / `AgentSideConnection` / stdio transport** — that's for a process speaking ACP directly. Flutter never speaks ACP; c1 does. We use only `acp_dart`'s **types** for serialization. (Requires the types to be usable without the connection layer — a verification item, §11.)

## 6. Components & interfaces

### 6.1 Transport — `infrastructure/agent/`
- `AgentStreamClient` — `Stream<(int seq, AguiEvent)> connect(String chatId, {int cursor})`. Wraps `flutter_client_sse`; decodes via `ag_ui`. Surfaces connection loss so the repository can reconnect from `MAX(seq)`.
- `AgentActionsApi` — one method per up-endpoint (§5.3), taking `acp_dart` types, returning the small JSON where present (`{runId}`) or void. Maps HTTP status → typed failures (§10).

### 6.2 Domain — `domain/agent/`
- **Events:** re-exported `ag_ui` event types. No local redefinition.
- **Up-channel + ambient values:** re-exported `acp_dart` types. **Anticipated exception:** if `acp_dart` lacks the elicitation response type, we author exactly one small DTO here (`ElicitationResponse`), documented as the sole hand-mirrored protocol type, guarded by the contract test.
- `ConversationReducer` — pure function `List<AguiEvent> → Conversation` (ordered messages: text, reasoning, tool-calls with args+result) `+ SessionState` (permission, elicitation, modes, config). No I/O. Highest-value unit-test target.

### 6.3 Persistence — `infrastructure/agent/cache/`
- Drift table `chat_events(chatId TEXT, seq INT, type TEXT, json TEXT, PRIMARY KEY(chatId, seq))`. Repository upserts each streamed event; conflict on `(chatId, seq)` overwrites (server wins). Cursor = `SELECT MAX(seq) FROM chat_events WHERE chatId = ?`. Reactive `watch(chatId) ORDER BY seq` drives the reducer. Storing raw event JSON (not normalized columns) is deliberate — new event/tool types need zero schema migration.

### 6.4 Application — `application/`
- `ChatCubit` — watches the cache → reduces → `ChatState`; owns the stream-subscription lifecycle (connect on open, reconnect on loss, close on leave); `sendPrompt`, `cancel`.
- `PermissionCubit` / `ElicitationCubit` / `SessionControlsCubit` (modes + config) — each reads its slice of `SessionState` and responds via `AgentActionsApi`.

### 6.5 Presentation — `presentation/`
- `chat_screen` (message list + tool cards + cancel), `permission_prompt` (reused/adapted), new `elicitation_form` (renders `requestedSchema`), `mode_switcher`, `config_picker`.

## 7. Cache semantics — server-authoritative, restated

1. The stream is the sole writer; the UI reads only the cache. Offline = last cached rows render; no write-back.
2. Conflict resolution is trivial and total: upsert by `(chatId, seq)`, server value wins. There is no client-side merge, no "which is newer" logic — the class of cache-reconciliation bugs the old cold/hot split had is removed by construction.
3. Cursor is derived (`MAX(seq)`), not separately tracked — nothing to get out of sync.

## 8. Backend pre-requisite: up-channel ACP conformance fix

For `acp_dart` types to drop into the up-channel verbatim, c1 must accept the true ACP body shapes. Audit of `agent.go`:

- **Already conformant:** `session/cancel` (`{}`), `session/set_mode` (`{modeId}`), `session/set_config_option` (binds `acpsdk.SetSessionConfigOptionRequest`).
- **Drifted — re-align (small handler edits + coordinator unwrap):**
  1. `session/prompt`: accept ACP `PromptRequest` (`prompt: ContentBlock[]`) instead of `{prompt: string}`. c1 already forwards a prompt to Goose; it now reads the first text block (and is forward-compatible with richer blocks).
  2. `session/request_permission/{id}`: accept `RequestPermissionResponse{outcome:{outcome,optionId}}` instead of `{optionId}`; the coordinator's option-offered check unwraps `outcome.optionId`.
  3. `session/elicitation/{id}`: accept ACP's `action` field instead of the current `outcome` field.

This restores contract §6.4 ("verbatim ACP up"), which the impl had flattened. It is scoped as a **conformance fix, not new capability**, and is a hard pre-req task in the plan. The existing c1 acceptance suite must stay 9/9 after it.

## 9. Out of scope / deferred (explicit)

- **PocketBase collections & the model pipeline — untouched.** No `export_schema.sh`, no `generate_models.py` run, no deletion of `message`/`permission`/`acp_terminal` models in this project. The client keeps its current `chats`/auth/config access as-is. A separate effort will decide the collection future; this spec must not depend on that decision. (Old `chat_repository`/`hitl` transport code is *replaced* and left dead-but-present; model files are not regenerated here.)
- **`session/fork`** — `acp_dart` supports it, but it creates a chat and belongs with chat-creation orchestration. Fast-follow, not v1.
- **Rich prompt content (image/audio/resource blocks)** — the `PromptRequest` type admits them; v1 UI sends text only.
- **`fs/*`, `terminal/*`, `document/*`, `nes/*` ACP client callbacks** — c1 answers these `unsupported` by architecture (Goose owns the workspace); file/terminal activity reaches Flutter as tool-call events. N/A to the client.

## 10. Error handling

- **Up (HTTP):** `202` accepted · `400` malformed/option-not-offered · `401` unauth · `404` chat-not-found/unknown-request/not-owner · `409` run-already-active · `503` agent-not-configured. `AgentActionsApi` maps each to a typed failure the cubits surface.
- **Down (stream):** `RUN_ERROR{code}` — `goose_unavailable`, `goose_replay_failed` (+ any bridge codes). Rendered inline in the conversation, not as a fatal.
- **Transport:** SSE drop → `flutter_client_sse` reconnect with `Last-Event-ID`; the cubit shows a transient "reconnecting" state, never loses cached history.

## 11. Testing strategy

- **`ConversationReducer` unit tests** (highest value, pure): curated event sequences → expected `Conversation` + `SessionState`, incl. interleaved tool-calls, reasoning, permission add/remove, mode/config deltas, replay-then-live-with-overlap (dedupe by seq).
- **Contract / golden parity tests** (the SDK safety net):
  - Down: decode **real captured c1 frames** (from the 2026-07-19 acceptance run) through `ag_ui`'s decoder — every frame must decode; catches Go-emit ↔ Dart-decode skew.
  - Up: serialize each `acp_dart` body and assert it matches the shape c1 accepts (post against a c1 fixture or asserted JSON) — catches Dart ↔ Go-SDK skew and pins the §8 re-alignment.
- **`AgentStreamClient`** — SSE frame parsing, cursor/`Last-Event-ID` resume, reconnect, against a fake stream.
- **Cubits** — fake repository; assert state transitions and that actions call the API without mutating local state directly.
- **Version pinning** — `ag_ui` and `acp_dart` pinned to exact versions; upgrading either re-runs the parity tests as the gate.

## 12. Security invariants (client side)

- Flutter addresses everything by `chatId`; it never sees or sends `goose_session_id`.
- Flutter never holds the Goose secret or ACP URL — those live only in c1.
- The only credential the client sends is the user's PB auth token, on the same-origin c1 endpoints it already uses.

## 13. Open questions (for spec review)

1. **`acp_dart` standalone types** — confirm the request/response types serialize without instantiating `ClientSideConnection` (§5.5). If not, we wrap minimally or fall back to hand-authored bodies for the affected types.
2. **Elicitation type presence** in `acp_dart` (§6.2) — confirm; if absent, the one-DTO exception applies.
3. **ACP protocol-version skew** — `acp_dart` (targets ACP ~0.1.0 wire) vs c1's `coder/acp-go-sdk@v0.13.5`. The parity tests are the guard; is any field known to differ today?
4. **Reducer location of `session_info`/title** — c1 emits a `/pocketcoder/session_info` delta (seen live); confirm we surface chat title from it vs. the `chats` record.

---

**Next:** independent spec review (including an Opus pass focused on the §5 connection plan — that we use `ag_ui`, `acp_dart`, SSE, and the JSON-Patch state model the way each is intended, and that the cursor/replay/reconnect handshake with c1 is exactly consistent). Then `writing-plans` → implementation plan, with the §8 c1 conformance fix as the first task.
