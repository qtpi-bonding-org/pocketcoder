# c1 ↔ Flutter Contract Spec

**Date:** 2026-07-19
**Status:** DRAFT CONTRACT — the target surface c1 must expose to Flutter. **Parked** pending the *Robust c1↔c2 ACP bridge* work (many endpoints below require bridge capabilities c1 does not have yet — see §9). This document defines *what the wire looks like*; the c1↔c2 spec defines *how c1 fulfills it*.
**Grounded against:** `coder/acp-go-sdk@v0.13.5`, `ag-ui-protocol/ag-ui` Go SDK (`@v0.0.0-20260716182252`), `internal/agent/{coordinator,agui,acp}`, `internal/api/agent.go`.

## 1. Purpose & layering

```
Flutter ⇄ [ AG-UI events over SSE  (down) ]  ⇄ c1 ⇄ [ ACP / JSON-RPC over WS ] ⇄ Goose
          [ ACP-shaped REST        (up)   ]        (c1 = authenticating ACP client)
```

- **Down** (server→client): a single long-lived SSE stream carrying **AG-UI** events. This is the UI-facing contract; c1's `agui.Bridge` translates ACP `session/update` and c1 state into flat, typed AG-UI events.
- **Up** (client→server): thin REST actions whose **bodies are verbatim ACP request payloads** with `sessionId` elided (c1 injects it from the `{chatId}` path param). Path mirrors the ACP method name.
- **ACP stays behind c1.** Flutter never speaks ACP directly, never sees `goose_session_id`, never holds the Goose secret.

## 2. Global invariants

1. **Auth:** every endpoint requires `apis.RequireAuth()` **and** chat ownership (`chats.user == auth.id`), 404 otherwise — matches the existing endpoints.
2. **No session-id leak:** Flutter addresses everything by `chatId`. c1 maps `chatId → goose_session_id` via the `goose_sessions` collection. `goose_session_id` never crosses to Flutter.
3. **No secret leak:** `GOOSE_SERVER__SECRET_KEY` and the Goose ACP URL never appear in any response.
4. **Verbatim ACP up:** request bodies equal the ACP payload minus `sessionId`. When ACP evolves a stable payload, our body follows it for free.
5. **Base path:** all routes under `/api/pocketcoder/chats/{chatId}/…`.

## 3. Transport

- **Down:** `Content-Type: text/event-stream`. Frames are `id: <seq>\n` + `data: <json>\n\n` (the current SSE writer omits `id:`; **adding a per-run monotonic `seq` as the SSE `id:` is required new work** — §9). `<json>` is one AG-UI event (`type` + fields, §5).
- **Up:** ordinary JSON `POST`s returning `202 Accepted` (+ small JSON where noted). Actions are asynchronous: their effect appears as events on the stream, never as the POST's body.
- **Heartbeat:** the stream emits an SSE comment (`: ping\n\n`) on an interval to keep intermediaries (Caddy/Tailscale) from idling the connection out.

## 4. The stream (down-channel semantics)

```
GET /api/pocketcoder/chats/{chatId}/stream?cursor=<seq>
```

One stream per open chat. Behavior:

- **Active run present:** replay the run **hub** buffer for events with `seq > cursor`, then live-tail until the run ends, then stay open idle.
- **No active run, no cursor:** replay bounded history from Goose (`session/load` → AG-UI, the current `ReplayReserved` path), then stay open idle, live-tailing the next run that starts on this chat.
- **Stays open across runs** (subscription-style). Sending a prompt does *not* open a new stream — its events flow down this one. Decision taken: persistent stream + heartbeats (best mobile UX) over per-run streams.
- **Multiple concurrent subscribers** allowed (multi-device / multi-tab); each gets replay-from-its-cursor + live tail.

**Detached-run model (the reason this contract exists):**
- A run executes on a **c1-owned background context**, not the request context. Client disconnect does **not** cancel it (removes today's `cancelOnClientDisconnect`).
- The **run hub** is an in-memory, append-only, `seq`-numbered buffer of the active run's AG-UI events plus a fan-out to N subscribers. It **lingers briefly after `RUN_FINISHED`** so a client reconnecting at the tail still gets the final events.
- **Cursor is per-run.** On reconnect the client sends `?cursor=<lastSeqSeen>`; if that run is still active it resumes seamlessly, else it gets fresh history.
- **Scope boundary:** survives *client* disconnect, **not** *c1 restart* (in-memory hub; Goose's own persistence covers durable history via replay). Full c1-restart durability is explicitly out of scope for v1.

## 5. Down-channel event catalog (AG-UI)

Every frame is `data: {"type": "...", ...}`. Field names below are the SDK's exact JSON tags. c1 emits only this subset; unknown ACP updates are dropped, not leaked.

### 5.1 Run lifecycle
| type | fields | meaning |
|---|---|---|
| `RUN_STARTED` | `threadId` (=chatId), `runId` | a turn (or a replay) began |
| `RUN_FINISHED` | `threadId`, `runId`, `outcome` | turn ended; c1 maps ACP `PromptResponse.stopReason` (`end_turn`/`max_tokens`/`max_turn_requests`/`refusal`/`cancelled`) into the outcome |
| `RUN_ERROR` | `message`, `code`, `runId` | failure; codes §7 |

### 5.2 Assistant text
| type | fields |
|---|---|
| `TEXT_MESSAGE_START` | `messageId`, `role:"assistant"` |
| `TEXT_MESSAGE_CONTENT` | `messageId`, `delta` |
| `TEXT_MESSAGE_END` | `messageId` |

### 5.3 Reasoning / thinking
| type | fields |
|---|---|
| `REASONING_MESSAGE_START` | `messageId`, `role:"assistant"` |
| `REASONING_MESSAGE_CONTENT` | `messageId`, `delta` |
| `REASONING_MESSAGE_END` | `messageId` |

### 5.4 Tool calls (this is how file edits, diffs, bash, search, todos all surface)
| type | fields |
|---|---|
| `TOOL_CALL_START` | `toolCallId`, `toolCallName` (ACP tool `Title`), `parentMessageId?` |
| `TOOL_CALL_ARGS` | `toolCallId`, `delta` (JSON-encoded ACP `rawInput`) |
| `TOOL_CALL_RESULT` | `toolCallId`, `messageId` (=`tool-result-<id>`), `content` |
| `TOOL_CALL_END` | `toolCallId` |

> There is **no** separate "file" or "terminal" event. A file edit is a tool call named e.g. `edit`/`write` whose args carry the path/diff and whose result carries the outcome. Rich rendering (diff view, terminal panel) is a Flutter concern driven off `toolCallName` + args/result. This is why `fs/*` and `terminal/*` ACP client-callbacks are **not** needed (§9).

### 5.5 Ambient session state (`STATE_SNAPSHOT` / `STATE_DELTA` on `/pocketcoder/*`)

c1 maintains a small state object mirrored to the client via AG-UI state events (JSON-Patch `delta` = `[{op,path,value}]`). Four namespaces:

**`/pocketcoder/permission`** — pending tool approval (already implemented). `STATE_DELTA`:
```json
{ "op":"add", "path":"/pocketcoder/permission",
  "value": { "requestId":"…", "status":"pending",
             "options":[ {"optionId":"…","name":"…","kind":"…"} ] } }
```
Cleared (`op:"remove"`) when answered/cancelled/timed-out.

**`/pocketcoder/elicitation`** — pending agent→user structured question (**Unstable ACP**, new work). Mirrors an ACP `unstable/create_elicitation` *form* request:
```json
{ "op":"add", "path":"/pocketcoder/elicitation",
  "value": { "elicitationId":"…", "message":"…", "mode":"…",
             "requestedSchema": { /* JSON Schema of the requested fields */ } } }
```

**`/pocketcoder/modes`** — available + current session modes (new work; c1 currently discards `SessionModeState`). `STATE_SNAPSHOT`/`STATE_DELTA`:
```json
{ "path":"/pocketcoder/modes",
  "value": { "currentModeId":"approve",
             "availableModes":[ {"id":"approve","name":"Approve","description":"…"} ] } }
```
Emitted on session load and whenever the mode changes.

**`/pocketcoder/config`** — available session config options + current values (new work; c1 currently discards `ConfigOptions`):
```json
{ "path":"/pocketcoder/config",
  "value": { "options":[
      {"kind":"boolean","id":"…","name":"…","currentValue":true},
      {"kind":"select","id":"…","name":"…","currentValue":"…",
       "values":[{"id":"…","name":"…"}]} ] } }
```

## 6. Up-channel endpoints (ACP-shaped REST)

### 6.1 Session interaction — verbatim ACP payload, `sessionId` elided

**`POST …/session/prompt`** → `session/prompt`. `202 {"runId":"…"}`.
```json
{ "prompt": [ { "type":"text", "text":"…" } ],   // ACP ContentBlock[] union (image/audio/resource_link too)
  "messageId": "optional-client-uuid" }
```
Fire-and-forget: turn completion arrives on the stream as `RUN_FINISHED` (see §5.1 semantics divergence). `409` if a run is already active for the chat.

**`POST …/session/cancel`** → `session/cancel` (ACP notification). Body `{}`. `202`.

**`POST …/session/set_mode`** → `session/set_mode`. `202`.
```json
{ "modeId": "approve" }
```
Valid `modeId`s come from `/pocketcoder/modes` (§5.5).

**`POST …/session/set_config_option`** → `session/set_config_option`. `202`. ACP union — boolean or select-value:
```json
{ "configId": "…", "value": true }
// or
{ "configId": "…", "valueId": "…" }
```

**`POST …/session/request_permission/{requestId}`** — the **response** to a pending approval. Body is the **verbatim ACP `RequestPermissionResponse`**. `202`.
```json
{ "outcome": { "outcome":"selected", "optionId":"…" } }
// or
{ "outcome": { "outcome":"cancelled" } }
```
`404` if `requestId` is unknown/already resolved; `400` if `optionId` was not among the offered options (existing coordinator checks).

**`POST …/session/elicitation/{elicitationId}`** — the **response** to a pending elicitation (**Unstable ACP**, new work). Body mirrors ACP accept/decline/cancel:
```json
{ "action":"accept",  "content": { /* fields per requestedSchema */ } }
// or { "action":"decline" }  |  { "action":"cancel" }
```

### 6.2 Session lifecycle — c1-orchestrated (NOT raw passthrough)

These touch the `chat ↔ session` mapping, so they are driven by **PocketBase chat CRUD + c1 orchestration**, never exposed as raw ACP endpoints (raw endpoints would allow orphaned/duplicate sessions):

- **New session** — created **lazily by c1** on the first `session/prompt` for a chat (`session/new`, then persist the `goose_sessions` mapping). No dedicated endpoint; the Flutter action is "create chat" (a normal `chats` record).
- **Load session** — c1-internal, on chat open / replay (`session/load`).
- **Close session** — c1 releases Goose resources when appropriate (`session/close`); lifecycle-managed, no Flutter endpoint in v1.
- **Delete session** — driven by **deleting the `chats` record**; c1 cascades to Goose (`session/delete`) and removes the mapping.
- **Fork session** (**Unstable ACP**, deferred to fast-follow) — "branch this chat." Requires: create a new `chats` record → ACP `unstable/fork_session(sourceSessionId, cwd)` → map new chat → forked `sessionId`. Because it creates a chat, it belongs with chat-creation orchestration; specced but **not v1**.

## 7. Error model

**HTTP (up):** `202` accepted · `400` malformed / option-not-offered · `401` unauthenticated · `404` chat-not-found / unknown request / not-owner · `409` run already active · `503` agent service not configured.

**Stream (down):** `RUN_ERROR` with `code`:
- `goose_unavailable` — dial/turn failure (exists)
- `goose_replay_failed` — replay failure (exists)
- (bridge-robustness codes TBD in the c1↔c2 spec, e.g. session-load failure, protocol error)

## 8. Deferred / excluded (with reasons — not scope-cutting)

- **`fs/read_text_file`, `fs/write_text_file`, `terminal/*`** — ACP *client callbacks* asking the client to touch files/shell. Here **Goose owns the workspace and runs its own tools**; c1 declares empty client capabilities on purpose. File/terminal activity reaches Flutter as **tool-call events** (§5.4). c1 continues to answer these `unsupported`. Excluded by architecture.
- **`document/*`, `nes/*`** — live-editor buffer sync + inline next-edit-suggestions. No open editor buffers on a mobile chat client. N/A.
- **`providers/list|set|disable`** (model/provider selection) — real feature, but owned by the **agent-definition revamp** (provider/model config). Excluded here to avoid double-building.
- **`mcp/*`** — c1/c3 plumbing, not a Flutter action.
- **`session/fork`, elicitation** — included in this contract but flagged **Unstable ACP**: the SDK marks these `Unstable*` ("not part of the spec yet, may change"). Elicitation is v1 (core HITL); fork is fast-follow. Both must track upstream and are candidates to break on ACP/Goose bumps.

## 9. Gap list — what c1 must gain to satisfy this contract

This is the bridge between this contract and the *Robust c1↔c2 bridge* spec. Today's c1 does **not** yet:

1. **Detach runs** from the request context (remove `cancelOnClientDisconnect`; run on a background ctx).
2. Provide a **run hub** — in-memory `seq`-numbered buffer + fan-out to N subscribers + post-finish linger.
3. Emit a **per-run monotonic `seq` as the SSE `id:`** (writer currently omits `id:`).
4. Serve **`GET …/stream`** as a persistent, cursor-resumable, cross-run subscription (today `runs` streams inline and `events` is one-shot + 409s during a run).
5. **Surface modes** (`SessionModeState`) and **config options** (`ConfigOptions`) it currently discards, as `/pocketcoder/modes` + `/pocketcoder/config` state.
6. Support **`set_mode`** beyond the hardcoded `approve`, and **`set_config_option`**.
7. Implement **elicitation** (client handler for `unstable/create_elicitation` + the response endpoint) — c1 currently handles only permission + 7 `unsupported` callbacks.
8. **Lifecycle orchestration**: cascade chat-delete → `session/delete`; manage `session/close`; (fast-follow) fork.
9. **Robustness**: reconnect/retry to Goose, clean per-run teardown, richer `RUN_ERROR` taxonomy, and correct multi-subscriber concurrency.

## 10. Open items for the c1↔c2 bridge spec (the parked continuation)

- Exact run-hub lifecycle: linger duration, buffer cap, back-pressure when a subscriber is slow.
- Multi-subscriber + single-writer concurrency model in the coordinator (today `emitMu` guards one writer).
- Goose reconnection strategy and how an in-flight turn survives a transient ACP WS blip (vs. c1 restart, which is out of scope).
- Mapping ACP `stopReason` → AG-UI `RUN_FINISHED` outcome shape.
- Whether `session/close` is driven by stream-subscriber count (last viewer leaves) or a timeout.
- Elicitation/fork stability tracking against Goose's ACP version on the pinned image.

---

**Next:** park this. Resume at the **Robust c1↔c2 ACP bridge** audit + spec (§9 is its backlog). This contract is the acceptance target the bridge builds toward; the Flutter client (a later project) consumes exactly what's above.
