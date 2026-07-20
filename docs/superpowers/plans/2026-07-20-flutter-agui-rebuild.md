# Flutter AG-UI Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-point the Flutter client at c1's AG-UI/ACP surface (full contract: prompt, streaming, cancel, permission, modes, config, elicitation), with Goose as the sole authority for history and a Goose-refreshed offline Drift mirror.

**Architecture:** Down-channel = AG-UI events over SSE decoded by the `ag_ui` Dart SDK; up-channel = ACP-shaped REST whose bodies are `acp_dart` types minus `sessionId`. c1 persists no event log — the only anchor is the existing `goose_sessions` row. Cold replay replaces the client cache (driven by a replay marker); warm resume appends by seq.

**Tech Stack:** Go (PocketBase/c1), Dart/Flutter (Cubits + injectable + freezed + Drift), `ag_ui`, `acp_dart`, `flutter_client_sse`, bats (backend acceptance).

**Design spec:** `docs/superpowers/specs/2026-07-20-flutter-agui-rebuild-design.md`

## Global Constraints

- **Security (verbatim):** Flutter never sees `goose_session_id`, never holds `GOOSE_SERVER__SECRET_KEY` or the Goose ACP URL; the only credential it sends is the user's PB auth token. c2 (Goose) has no PB DB access and no published port.
- **PocketBase collections & the model pipeline are OUT OF SCOPE.** No `export_schema.sh`, no `generate_models.py`, no model regeneration, no collection edits. Do not delete `message`/`permission`/`acp_terminal` model files (leave dead).
- **Protocol types are never hand-mirrored.** Down = `ag_ui` types; up = `acp_dart` types. The single allowed hand-authored protocol DTO is the elicitation response (Task 9) — `acp_dart` ships none.
- **Backend regression gate:** the c1 acceptance suite (`tests/agent-c1/acceptance.bats`) must stay **9/9** after every Phase 0 task.
- **Pinned SDK versions:** `ag_ui` and `acp_dart` pinned to exact versions; any bump re-runs the parity tests (Tasks 7, 9).
- **Model note:** local testing uses the real MiniMax model; VPS is down, so all testing is local. Test user: `agent-test@example.com` / `test-password-1234`.

---

# PHASE 0 — Backend correctness fixes (Go)

These land first. They are prerequisites for a correct client and were surfaced by the Opus connection-plan review. Build/run after each: `docker compose build pocketbase && docker compose up -d pocketbase`, then `cd tests && bats agent-c1/acceptance.bats` must stay 9/9.

## Task 1: Unify the SSE `seq` counter (hub-global monotonic)

**Problem:** cold replay uses its own `seq := 0` counter (`run.go:469`) independent of the live hub counter (`hub.go:59`), so one stream can emit `id:1..N` (replay) then `id:1..M` (live) — non-monotonic ids break within-session resume.

**Files:**
- Modify: `services/pocketbase/internal/agent/coordinator/hub.go`
- Modify: `services/pocketbase/internal/agent/coordinator/run.go:467-505` (StreamColdReplay), add `NextSeq` on Coordinator
- Modify: `services/pocketbase/internal/api/agent.go:111-125` (snapshot/error frames)
- Test: `services/pocketbase/internal/agent/coordinator/hub_test.go`

**Interfaces:**
- Produces: `func (h *ChatHub) nextSeq() int` (locks, `h.seq++`, returns) and `func (c *Coordinator) NextSeq(chatID string) int` (via `hubFor`). `Publish` refactored to use an unlocked `nextSeqLocked()`.

- [ ] **Step 1: Write the failing test** — in `hub_test.go`:
```go
func TestColdReplayAndLiveShareOneMonotonicSeq(t *testing.T) {
	h := NewChatHub(NewFakeClock(time.Unix(0, 0)), 30*time.Second, 8)
	// Simulate a cold replay allocating 3 seqs, then a live run allocating 2.
	a, b, c := h.nextSeq(), h.nextSeq(), h.nextSeq()
	h.StartRun("run-1", func() []events.Event { return nil })
	d := h.Publish(textEv("x"))
	e := h.Publish(textEv("y"))
	got := []int{a, b, c, d, e}
	for i := 1; i < len(got); i++ {
		if got[i] != got[i-1]+1 {
			t.Fatalf("seqs not strictly monotonic: %v", got)
		}
	}
	if a != 1 || e != 5 {
		t.Fatalf("want 1..5, got %v", got)
	}
}
```
- [ ] **Step 2: Run it, verify it fails** — `go test ./internal/agent/coordinator/ -run TestColdReplayAndLiveShareOneMonotonicSeq` → FAIL (`nextSeq` undefined).
- [ ] **Step 3: Implement** — in `hub.go` add:
```go
func (h *ChatHub) nextSeq() int {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.nextSeqLocked()
}
func (h *ChatHub) nextSeqLocked() int { h.seq++; return h.seq }
```
Change `Publish` to use `nextSeqLocked()` in place of the bare `h.seq++` (Publish already holds `h.mu`). In `run.go`, add `func (c *Coordinator) NextSeq(chatID string) int { return c.hubFor(chatID).nextSeq() }`, and in `StreamColdReplay` replace the local counter:
```go
emitSeq := func(ev events.Event) error {
	return emit(c.hubFor(chatID).nextSeq(), ev)
}
```
(delete `seq := 0`).
- [ ] **Step 4: Fix the borrowed-cursor frames** in `agent.go` — replace the three `writeFlush(..., cursor, ...)` / `writeSeqFrame(..., cursor, ...)` calls at lines ~114, ~120, ~124 with a hub-allocated seq: `service.NextSeq(chatID)` for each. Note the two paths are mutually exclusive branches of `hub.Attach`: lines ~114/~120 are the **cold-replay** `RUN_ERROR` fallbacks (`ColdReplayNeeded`), while the `att.Snapshot` loop at ~123-125 is the **active-run attach** path (`h.active != nil`). Both currently borrow `cursor`; both must get a real hub-allocated seq.
- [ ] **Step 5: Run tests** — `go test ./internal/agent/...` PASS; rebuild container; `bats agent-c1/acceptance.bats` → 9/9.
- [ ] **Step 6: Commit** — `git commit -m "fix(agent): unify SSE seq counter across cold replay, live, and catch-up frames"`

## Task 2: Emit a cold-replay "replace" marker

**Files:**
- Modify: `services/pocketbase/internal/agent/agui/bridge.go` (add `ReplayStarted`)
- Modify: `services/pocketbase/internal/agent/coordinator/run.go` (StreamColdReplay emits it first)
- Test: `services/pocketbase/internal/agent/agui/bridge_test.go`

**Interfaces:**
- Produces: `func (b *Bridge) ReplayStarted() events.Event` → an AG-UI `CUSTOM` event `name:"pocketcoder:sync"`, `value:{"mode":"replace"}`. (Bridge already emits `CUSTOM` events, e.g. `pocketcoder:tool` — same `events.NewCustomEvent` constructor.)

- [ ] **Step 1: Write the failing test** — assert `ReplayStarted()` is a CUSTOM event named `pocketcoder:sync` carrying `mode:replace`:
```go
func TestReplayStartedIsReplaceMarker(t *testing.T) {
	b := NewBridge("chat-1", "run-1")
	ev := b.ReplayStarted()
	if ev.Type() != events.EventTypeCustom { t.Fatalf("want CUSTOM, got %v", ev.Type()) }
	// name + value assertions per the CustomEvent accessor shape
}
```
- [ ] **Step 2: Run, verify fail** — undefined `ReplayStarted`.
- [ ] **Step 3: Implement** in `bridge.go`:
```go
// ReplayStarted marks the head of a cold replay so the client discards its
// cached view and rebuilds from this replay (Goose is authority). Distinct
// from Started() which begins a live turn.
func (b *Bridge) ReplayStarted() events.Event {
	return events.NewCustomEvent("pocketcoder:sync", events.WithValue(map[string]any{"mode": "replace"}))
}
```
(the option is `events.WithValue`, confirmed at the existing `pocketcoder:tool` call site `internal/agent/agui/custom.go:26`.) In `StreamColdReplay`, emit it as the very first frame, before `bridge.Started()`:
```go
if err := emitSeq(bridge.ReplayStarted()); err != nil { return err }
if err := emitSeq(bridge.Started()); err != nil { return err }
```
- [ ] **Step 4: Run tests** — `go test ./internal/agent/...` PASS; rebuild; `bats` 9/9 (acceptance test 5 asserts `RUN_STARTED` present on cold replay — the marker precedes it, so it still passes; confirm).
- [ ] **Step 5: Commit** — `git commit -m "feat(agent): emit pocketcoder:sync replace marker at cold-replay head"`

## Task 3: Live `modes` delta preserves `availableModes`

**Problem:** `bridge.go:90` `set("modes", {currentModeId})` emits `op:add` replacing the whole `/pocketcoder/modes` subtree, wiping `availableModes` until the next snapshot.

**Files:**
- Modify: `services/pocketbase/internal/agent/agui/state.go` (add `setSub`)
- Modify: `services/pocketbase/internal/agent/agui/bridge.go:90`
- Test: `services/pocketbase/internal/agent/agui/state_test.go` (or `bridge_test.go`)

**Interfaces:**
- Produces: `func (p *projection) setSub(ns, key string, value any) events.Event` → patches `/pocketcoder/<ns>/<key>` and preserves siblings in the stored state map.

- [ ] **Step 1: Write the failing test** — seed modes with `availableModes`, then apply a `CurrentModeUpdate`, assert the snapshot still contains `availableModes`:
```go
func TestCurrentModeUpdateKeepsAvailableModes(t *testing.T) {
	b := NewBridge("c", "r")
	b.SeedSession(&acpsdk.SessionModeState{CurrentModeId: "auto",
		AvailableModes: []acpsdk.SessionMode{{Id: "auto", Name: "auto"}, {Id: "chat", Name: "chat"}}}, nil)
	_, _ = b.Update(acpsdk.SessionUpdate{CurrentModeUpdate: &acpsdk.CurrentModeUpdate{CurrentModeId: "chat"}})
	snap := b.Snapshot() // STATE_SNAPSHOT
	// assert snapshot /pocketcoder/modes has availableModes length 2 AND currentModeId == "chat"
}
```
- [ ] **Step 2: Run, verify fail** — `availableModes` missing after the mode update.
- [ ] **Step 3: Implement** `setSub` in `state.go`:
```go
func (p *projection) setSub(ns, key string, value any) events.Event {
	p.ensure()
	sub, ok := p.state[ns].(map[string]any)
	if !ok {
		sub = map[string]any{}
		p.state[ns] = sub
	}
	sub[key] = value
	return events.NewStateDeltaEvent([]events.JSONPatchOperation{{
		Op: "add", Path: "/pocketcoder/" + ns + "/" + key, Value: value,
	}})
}
```
Change `bridge.go:90` to `b.state.setSub("modes", "currentModeId", string(update.CurrentModeUpdate.CurrentModeId))`.
- [ ] **Step 4: Run tests** — PASS; rebuild; `bats` 9/9.
- [ ] **Step 5: Commit** — `git commit -m "fix(agent): current-mode delta preserves availableModes"`

## Task 4: Up-channel ACP conformance (verbatim ACP bodies)

**Files:**
- Modify: `services/pocketbase/internal/api/agent.go` (prompt, request_permission, elicitation handlers)
- Modify: `services/pocketbase/internal/agent/coordinator/run.go` (permission cancel path)
- Test: `tests/agent-c1/acceptance.bats` (update body shapes) + a new isolated handler test if the suite exists

**Interfaces:**
- Consumes: `acpsdk.PromptRequest`, `acpsdk.RequestPermissionResponse` shapes.
- Produces: `func (c *Coordinator) DenyPermission(chatID, requestID string) error` (sends `permissionDecision{cancelled:true}`, mirroring `dropPendingForChat`).

- [ ] **Step 1 (prompt):** change the `session/prompt` handler to bind `acpsdk.PromptRequest`, extract the first text `ContentBlock` into the string passed to `StartPrompt`. Reject `400` if no text block. Keep `StartPrompt(chatID, prompt string, …)` unchanged.
- [ ] **Step 2 (permission):** change `request_permission/{id}` to bind `acpsdk.RequestPermissionResponse`; switch on `outcome.outcome`: `"selected"` → `service.Approve(ctx, chatID, id, outcome.optionId)`; `"cancelled"` → `service.DenyPermission(chatID, id)`. Add `DenyPermission` to the coordinator (send `cancelled:true` to the pending decision channel; `ErrNoPendingPermission` if absent).
- [ ] **Step 3 (elicitation):** change `elicitation/{id}` to bind ACP's `action` field (`accept`/`decline`/`cancel`) instead of `outcome`, building `acpsdk.UnstableCreateElicitationResponse` as today.
- [ ] **Step 4:** update **both** occurrences of each body shape in `tests/agent-c1/acceptance.bats` (verified: the `{"prompt":"…"}` body appears at `:103` and `:241`; the `{"optionId":"…"}` body at `:154` and `:302`). New shapes: permission response `{"outcome":{"outcome":"selected","optionId":"…"}}`; prompt `{"prompt":[{"type":"text","text":"…"}]}`. Grep to confirm no stale occurrence remains before rebuilding.
- [ ] **Step 5:** rebuild; `bats agent-c1/acceptance.bats` → 9/9 with the new bodies.
- [ ] **Step 6: Commit** — `git commit -m "fix(agent): up-channel accepts verbatim ACP bodies (prompt/permission/elicitation)"`

**Capture the golden corpus now:** while the suite runs, save a live cold-replay + live-turn SSE dump (with the new marker and monotonic seqs) to `client/packages/pocketcoder_flutter/test/fixtures/agui_frames.jsonl` — the down-parity fixtures for Task 7. One event per line (the `data:` JSON).

---

# PHASE 1 — Flutter foundations

Working dir for all Flutter tasks: `client/packages/pocketcoder_flutter`. After codegen steps run `dart run build_runner build --delete-conflicting-outputs`.

## Task 5: Add pinned SDK deps + confirm standalone `acp_dart` serialization

**Files:** Modify `pubspec.yaml`; Create `test/spikes/acp_dart_serialize_test.dart`.

- [ ] **Step 1:** add to `pubspec.yaml` dependencies, pinned to exact current versions (resolve with `dart pub add`): `ag_ui: <pinned>`, `acp_dart: <pinned>`, and **`drift_flutter: <pinned>`** (needed for `driftDatabase()` in Task 6 — core `drift` does not export it; `path`/`path_provider` are the fallback). `flutter_client_sse`, `drift`, and `http` are already present.
- [ ] **Step 2 (spike = §13 Q1):** write `test/spikes/acp_dart_serialize_test.dart` that constructs `PromptRequest`, `RequestPermissionResponse`, `SetSessionModeRequest`, `SetSessionConfigOptionRequest` and calls `.toJson()` **without** any `ClientSideConnection`, asserting the JSON shape. Run it.
- [ ] **Step 3:** if any type is not standalone-serializable, record the deviation in the spec's §13 Q1 and adjust Task 9 (wrap minimally). Expected: all pass.
- [ ] **Step 4: Commit** — `git commit -m "chore(flutter): pin ag_ui + acp_dart; confirm standalone acp serialization"`

## Task 6: Agent Drift cache (`chat_events`)

Use a dedicated Drift database for the agent cache (do not entangle with pocketbase_drift's schema).

**Files:** Create `lib/infrastructure/agent/cache/agent_cache_db.dart` (+ `.g.dart`); Test `test/infrastructure/agent/agent_cache_db_test.dart`.

**Interfaces:**
- Produces: `class AgentCacheDb` with `Future<void> upsertEvent(String chatId, int seq, String type, String json)`, `Stream<List<CachedEvent>> watchChat(String chatId)` (ORDER BY seq), `Future<int?> maxSeq(String chatId)`, `Future<void> clearChat(String chatId)`.

- [ ] **Step 1: Write failing tests** — upsert-by-`(chatId,seq)` overwrites; `watchChat` emits ordered rows; `maxSeq` returns the high-water; `clearChat` empties one chat only.
- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** the `@DriftDatabase` with table `ChatEvents` (`chatId TEXT, seq INT, type TEXT, json TEXT`, PK `(chatId, seq)`), in-memory `NativeDatabase.memory()` for tests, on-disk for prod via `driftDatabase(name:'agent_cache')` (from `drift_flutter`, added in Task 5) — or, if `drift_flutter` is undesirable, `LazyDatabase(() => NativeDatabase.createInBackground(File('${(await getApplicationSupportDirectory()).path}/agent_cache.sqlite')))` using `path_provider`.
- [ ] **Step 4: Run, PASS.** Register `AgentCacheDb` as `@lazySingleton` (or via a DI module).
- [ ] **Step 5: Commit** — `git commit -m "feat(flutter): agent Drift cache (chat_events, server-authoritative mirror)"`

## Task 7: AG-UI decode wrapper + down-parity golden test

**Files:** Create `lib/infrastructure/agent/agui_decode.dart`; Test `test/infrastructure/agent/agui_parity_test.dart` (uses `test/fixtures/agui_frames.jsonl` from Task 4).

**Interfaces:**
- Produces: `DecodedFrame decodeAguiFrame(String dataJson)` where `DecodedFrame = ({String rawJson, AguiEvent event})` — it retains the raw JSON string so the cache (Task 6, `upsertEvent(..., String json)`) can persist the raw event without a lossy re-encode round-trip. Wraps `ag_ui`'s `EventDecoder`/event factory (verify exact API against pinned `ag_ui`). A typed helper `bool isReplaceMarker(AguiEvent)` for the `pocketcoder:sync` CUSTOM event.

- [ ] **Step 1: Write the failing parity test** — read every line of `agui_frames.jsonl`, `decodeAguiFrame` each, assert none throw and each yields the expected `ag_ui` event subtype (RUN_STARTED, TEXT_MESSAGE_CONTENT, TOOL_CALL_*, STATE_DELTA, the CUSTOM sync marker, etc.).
- [ ] **Step 2: Run, verify fail** (`decodeAguiFrame` undefined).
- [ ] **Step 3: Implement** `agui_decode.dart` using the `ag_ui` decoder (confirm whether it accepts a `Map` or `String`; `jsonDecode` accordingly — review noted this is the intended standalone path).
- [ ] **Step 4: Run, PASS.** This test is the Go-emit ↔ Dart-decode drift gate; it re-runs on any `ag_ui` bump.
- [ ] **Step 5: Commit** — `git commit -m "feat(flutter): ag_ui decode wrapper + down-channel parity golden test"`

---

# PHASE 2 — Transport

## Task 8: `AgentStreamClient` (SSE + decode + replay marker + explicit reconnect)

**Files:** Create `lib/infrastructure/agent/agent_stream_client.dart`; Test `test/infrastructure/agent/agent_stream_client_test.dart`.

**Interfaces:**
- Consumes: injected `PocketBase` (for `baseURL` + `authStore.token`), `http.Client`, `decodeAguiFrame` (Task 7).
- Produces: `Stream<StreamFrame> connect(String chatId, {required int cursor})` where `StreamFrame = ({int seq, String rawJson, AguiEvent event})` — `rawJson` carries through to the cache (finding: nothing else retains the raw string). The stream **completes on disconnect** so the caller (`ChatCubit`) reconnects with a fresh cursor. Reconnect is caller-driven, not internal.

> **Blocker fixed here (Sonnet review):** the pinned `flutter_client_sse@2.0.3` `SSEClient.subscribeToSSE` **cannot** be used as-is — on any error it auto-retries after 5s reusing the *stale* `?cursor=` baked into the first call, feeds into the same `StreamController` (so the stream never completes), and shares a global `static` client. That silently defeats caller-driven reconnect (spec §5.1). A fake-source unit test would not catch it. We therefore **hand-roll the SSE read** over `http.Client` (the frame parsing is ~25 trivial lines) instead of calling `subscribeToSSE`.

- [ ] **Step 1: Write failing tests** (fake `http.Client` streaming a byte body): frames `id: N\n data: {json}\n\n` parse to `(seq:N, rawJson, event)`; `: ping` comment lines are skipped; multi-frame bodies split correctly; the request URL includes `?cursor=<n>`; the `Authorization` header equals `pb.authStore.token`; **on body close the returned stream completes** (does not hang or auto-retry).
- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** a hand-rolled reader: `http.Request('GET', Uri.parse('${pb.baseURL}/api/pocketcoder/chats/$chatId/stream?cursor=$cursor'))` with header `{'Authorization': pb.authStore.token}`, send via the injected `http.Client`, then parse the streamed response body line-by-line into SSE frames (accumulate `id:`/`data:`, dispatch on blank line, skip `:`-comments), mapping `id`→seq and `data`→`decodeAguiFrame`. Complete the stream when the body ends or errors; do **not** retry internally.
- [ ] **Step 4: Run, PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(flutter): AgentStreamClient (authed SSE → ag_ui events)"`

## Task 9: `AgentActionsApi` (acp_dart bodies) + elicitation DTO + up-parity test

**Files:** Create `lib/infrastructure/agent/agent_actions_api.dart`; Create `lib/domain/agent/elicitation_response.dart` (the one hand-authored DTO); Test `test/infrastructure/agent/agent_actions_parity_test.dart`.

**Interfaces:**
- Consumes: injected `PocketBase` (`_pb.send(path, method:'POST', body:…)`).
- Produces methods, each `sessionId`-elided, returning parsed result or void:
  - `Future<String> prompt(String chatId, String text)` → POST `session/prompt`, body from `PromptRequest([TextBlock(text)])`, returns `runId`.
  - `Future<void> cancel(String chatId)` → `session/cancel`, `{}`.
  - `Future<void> setMode(String chatId, String modeId)` → `SetSessionModeRequest`.
  - `Future<void> setConfigOption(String chatId, SetSessionConfigOptionRequest req)`.
  - `Future<void> respondPermission(String chatId, String requestId, {String? optionId, bool cancelled = false})` → `RequestPermissionResponse` (`selected`/`cancelled`).
  - `Future<void> respondElicitation(String chatId, String elicitationId, ElicitationResponse resp)`.

- [ ] **Step 1: Write the up-parity test** — for each method, capture the JSON body it would POST (inject a fake `PocketBase.send` recorder) and assert it equals the shape c1 now accepts after Task 4 (e.g. permission → `{"outcome":{"outcome":"selected","optionId":"x"}}`; prompt → `{"prompt":[{"type":"text","text":"hi"}]}`).
- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** `ElicitationResponse` (freezed: `accept{content}` | `decline` | `cancel`) and `AgentActionsApi` using `acp_dart` types' `.toJson()` with `sessionId` removed. Map **all five** HTTP statuses from spec §10 to typed failures — `400`→`BadRequest`, `401`→`Unauthenticated`, `404`→`NotFound`, `409`→`RunInProgress`, `503`→`AgentUnavailable` — and add a test asserting each status raises the right failure (not just 404/409).
- [ ] **Step 4: Run, PASS.** This is the Dart↔Go-SDK up-drift gate.
- [ ] **Step 5: Commit** — `git commit -m "feat(flutter): AgentActionsApi (acp_dart bodies) + elicitation DTO + up-parity test"`

---

# PHASE 3 — Domain reduction

## Task 10: `ConversationReducer`

**Files:** Create `lib/domain/agent/conversation.dart` (freezed `Conversation`, `ChatMessage`, `ToolCall`, `SessionState`); Create `lib/domain/agent/conversation_reducer.dart`; Test `test/domain/agent/conversation_reducer_test.dart`.

**Interfaces:**
- Produces: `Conversation reduce(List<AguiEvent> events)` → ordered messages (text/reasoning) + tool-calls (args+result) + `SessionState` (permission, elicitation, modes, config, plan, session_info/title). `commands`/`usage` parsed-past, not surfaced (documented).

- [ ] **Step 1: Write failing tests** (pure, highest value — one behavior each):
  - text START/CONTENT×2/END → one assistant message with concatenated text.
  - reasoning START/CONTENT/END → one reasoning block.
  - TOOL_CALL_START/ARGS/RESULT/END → one tool-call with name, args, result.
  - STATE_DELTA add `/pocketcoder/permission` then remove → permission present then cleared.
  - STATE_DELTA add `/pocketcoder/elicitation` → elicitation form (with `requestedSchema`) surfaced in `SessionState`.
  - STATE_DELTA/`STATE_SNAPSHOT` `/pocketcoder/config` → config options surfaced.
  - `modes` snapshot + `CurrentModeUpdate` sub-path delta → `currentModeId` updated, `availableModes` **retained** (guards Task 3).
  - sub-path patch (`/pocketcoder/modes/currentModeId`) applied when parent absent → parent created, no throw.
  - `session_info` delta → title surfaced.
  - **replace marker:** a `pocketcoder:sync` CUSTOM event resets the accumulator (events before it are discarded).
- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** the reducer: fold events in order; maintain open message/tool builders keyed by id; own a `/pocketcoder/*` map, applying JSON-Patch deltas (clone before apply — `ag_ui`'s `applyJsonPatch` mutates in place) and resetting subtrees on snapshot; hydrate `acp_dart`-typed values. On the replace marker, clear all accumulated state.
- [ ] **Step 4: Run, PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(flutter): ConversationReducer (AG-UI events → Conversation + SessionState)"`

---

# PHASE 4 — Application (Cubits)

## Task 11: `AgentChatRepository` + `ChatCubit`

**Files:** Create `lib/infrastructure/agent/agent_chat_repository.dart`; Create `lib/application/agent/chat_cubit.dart` + `chat_state.dart`; Tests alongside.

**Interfaces:**
- `AgentChatRepository` — wires `AgentStreamClient` → `AgentCacheDb`: on connect, for each `StreamFrame` either **replace** (on `isReplaceMarker(frame.event)`: `clearChat` then ingest) or **upsert** via `upsertEvent(chatId, frame.seq, frame.event.type, frame.rawJson)` (raw JSON from the frame, no re-encode); exposes `Stream<Conversation> watch(String chatId)` (from `AgentCacheDb.watchChat` → `decodeAguiFrame(row.json).event` → `reduce`) and `Future<int> cursorFor(String chatId)` (`maxSeq ?? 0`). Delegates actions to `AgentActionsApi`.
- `ChatCubit` — `open(chatId)` starts the stream at `cursorFor`, reconnects on drop with a fresh `cursorFor`; `sendPrompt(text)`, `cancel()`; emits `ChatState` from the reduced `Conversation`.

- [ ] **Step 1: Write failing tests** (fake stream client + real in-memory `AgentCacheDb`): replace-marker path clears then rebuilds; warm frames upsert; `sendPrompt` calls the API and does **not** mutate local state directly (effect arrives via the stream); reconnect uses `maxSeq` as cursor.
- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** repository + cubit + freezed `ChatState`.
- [ ] **Step 4: Run, PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(flutter): AgentChatRepository + ChatCubit (replace-on-marker, warm append)"`

## Task 12: Permission / Elicitation / SessionControls cubits

**Files:** Create `lib/application/agent/{permission_cubit,elicitation_cubit,session_controls_cubit}.dart` + states; Tests alongside.

**Interfaces:** each reads its slice of `SessionState` (from `ChatCubit`/repository stream) and responds via `AgentActionsApi` (`respondPermission`, `respondElicitation`, `setMode`, `setConfigOption`).

- [ ] **Step 1: Write failing tests** — a pending permission in state surfaces in `PermissionCubit`; `authorize`/`deny` call `respondPermission` with the right args; `ElicitationCubit.submit` posts the DTO; `SessionControlsCubit.selectMode/setOption` call the API.
- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** the three cubits + freezed states.
- [ ] **Step 4: Run, PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(flutter): permission/elicitation/session-controls cubits"`

---

# PHASE 5 — Presentation & wiring

## Task 13: Rewire `chat_screen` + widgets

**Files:** Modify `lib/presentation/chat/chat_screen.dart`; Modify `lib/presentation/core/widgets/permission_prompt.dart`; Create `lib/presentation/agent/{elicitation_form,mode_switcher,config_picker,plan_panel}.dart`.

- [ ] **Step 1:** rebuild `chat_screen` on `BlocBuilder<ChatCubit, ChatState>` rendering the reduced `Conversation` (messages + tool cards), the title (from `session_info`), a cancel button (while a run is active), and the plan panel.
- [ ] **Step 2:** adapt `permission_prompt` to the new `SessionState.permission`; wire allow/deny → `PermissionCubit`.
- [ ] **Step 3:** build `elicitation_form` (renders `requestedSchema` → inputs → `ElicitationCubit.submit`), `mode_switcher` (`SessionControlsCubit`), `config_picker` (`SessionControlsCubit`).
- [ ] **Step 4:** widget tests for each (pump with a fake cubit/state; assert rendering + tap→cubit call).
- [ ] **Step 5: Commit** — `git commit -m "feat(flutter): chat screen + HITL/mode/config/plan widgets on AG-UI"`

## Task 14: DI wiring, remove dead transport, smoke test

**Files:** Modify DI module(s) under `lib/infrastructure/core/`; delete-or-detach old transport imports; rerun codegen.

- [ ] **Step 1:** register `AgentCacheDb`, `AgentStreamClient`, `AgentActionsApi`, `AgentChatRepository`, and the new cubits with injectable; run `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 2:** **Delete the concrete files** (not just references — `@InjectableInit()` at `lib/app/bootstrap.dart:18` source-scans the whole package for `@injectable` annotations, so a dead `@injectable` cubit keeps auto-registering with broken deps unless the file is removed): `lib/application/chat/chat_cubit.dart` (+ `chat_state.dart` + generated siblings), `lib/infrastructure/communication/chat_repository.dart`, `communication_daos.dart`, `lib/infrastructure/hitl/hitl_daos.dart`, `hitl_repository.dart`, and their now-unused domain interfaces (`domain/communication/i_chat_repository.dart`, `domain/hitl/i_hitl_repository.dart`) if nothing else references them. **Explicitly preserve** the model files per Global Constraints: `lib/domain/models/{message,permission,acp_terminal}.dart` and their `.freezed.dart`/`.g.dart` siblings. Re-run `build_runner`; then `flutter analyze` must be clean (no dangling imports).
- [ ] **Step 3:** local end-to-end smoke against the running stack (containers up, test user): open a chat, send "Reply with exactly: hello", observe streamed text; trigger a tool + permission; switch mode; confirm cold-open replay renders after leaving+reopening. Document the run.
- [ ] **Step 4:** `flutter test` (full suite) green.
- [ ] **Step 5: Commit** — `git commit -m "feat(flutter): wire AG-UI agent stack; retire legacy chat/HITL transport"`

---

## Self-Review (completed)

- **Spec coverage:** §8 backend fixes → Tasks 1–4; canonical stack (`ag_ui`/`acp_dart`) → Tasks 5,7,9; Goose-authority cache + replace-marker → Tasks 2,6,10,11; all 8 state namespaces + modes fix → Tasks 3,10; full contract UI → Tasks 12–13; PB-collections-untouched honored throughout (Global Constraints, Task 14 Step 2). Parity/golden tests → Tasks 7,9. Security invariants → Tasks 8,9.
- **Type consistency:** `decodeAguiFrame`/`isReplaceMarker` (Task 7) used in Tasks 8,10,11; `AgentCacheDb` API (Task 6) used in Task 11; `ElicitationResponse` (Task 9) used in Task 12; `Conversation`/`SessionState` (Task 10) used in Tasks 11–13.
- **Known unknowns flagged in-task (not placeholders):** exact `ag_ui` decoder + `NewCustomEvent`/`events.WithCustomValue` and `acp_dart` type/method names must be confirmed against the pinned SDK versions during Tasks 5/7 — the parity tests (7,9) are the gate that makes this safe rather than guessed.

**Execution:** subagent-driven recommended (fresh subagent per task, review between). Phase 0 must complete and keep the c1 acceptance suite 9/9 before Phase 1 begins.
