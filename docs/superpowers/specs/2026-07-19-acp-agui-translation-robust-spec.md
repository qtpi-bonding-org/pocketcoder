# Robust ACP → AG-UI Translation — Spec

**Date:** 2026-07-19
**Status:** DRAFT SPEC — ready for user review, then a plan. Scoped to the translation layer only.
**Motivated by:** the audit showing `internal/agent/agui/bridge.go` is a happy-path — it handles 4 of ~12 `SessionUpdate` variants, 1 of 3 content-block types, 1 of 3 tool-content types, and drops the rest silently.
**Grounded against:** `coder/acp-go-sdk@v0.13.5`, `ag-ui-protocol/ag-ui` Go SDK. Reference reviewed (not adopted as law): `github.com/namanrajpal/acp-to-agui` — we borrow its *never-drop → CUSTOM* idea and confirm its `STATE`-for-permission pattern; it does not map diffs/terminal/plan, which we do.

## 1. Goal & scope

Make the ACP→AG-UI translation **complete and robust**: every ACP `SessionUpdate` variant, every content-block type, and every tool-content type maps to a defined AG-UI output, with **nothing silently dropped**. Fix the correctness holes (single-shot tool calls, fail-closed errors, replay of user messages).

**In scope:** the pure translation unit — `internal/agent/agui/*`. Input: ACP `SessionNotification`/lifecycle + the ACP session-init responses (modes/config). Output: `[]events.Event` (AG-UI) + a projected session-state model with `Snapshot()`.

**Out of scope (other specs):** the run hub / detached runs / SSE endpoints / cursor (the *c1↔c2 bridge* spec). This unit only *produces* events; the hub buffers/fans them out and calls `Snapshot()` for late joiners.

## 2. Design principles

1. **Never drop.** Unknown, vendor (`_*.dev/…`), or unmapped-Unstable variants emit a `RAW` AG-UI event carrying the original payload — observable and forward-compatible, never invisible.
2. **Two output channels, one rule:**
   - **Standard AG-UI events** (`TEXT_*`, `REASONING_*`, `TOOL_CALL_*`, `RUN_*`) carry the linear, text-first timeline a dumb client can render alone.
   - **`STATE_SNAPSHOT`/`STATE_DELTA` on `/pocketcoder/*`** carry **bounded, current-value** state (snapshot-able for re-attach).
   - **`CUSTOM pocketcoder:*` events** carry **per-timeline-item structured enrichment** (unbounded, anchored to a message/tool id) that rich clients consume and dumb clients ignore.
   - Rule: *bounded current-value → STATE; unbounded timeline enrichment → CUSTOM.*
3. **Side-channels don't perturb the text machine.** STATE/CUSTOM emissions never open/close the text/reasoning/tool boundary state; adding them is low-risk to the existing (correct) state machine.
4. **Non-fatal by default.** A single malformed/unmappable update is logged and emitted as `RAW`, never aborts the turn. Only a genuinely fatal transport error propagates.

## 3. Complete `SessionUpdate` mapping

| ACP `SessionUpdate` | AG-UI output | Notes |
|---|---|---|
| `UserMessageChunk` | `TEXT_MESSAGE_START/CONTENT/END` role `user` | **Fixes replay** — reconstructs the user's own prompts on `session/load` |
| `AgentMessageChunk` | `TEXT_MESSAGE_START/CONTENT/END` role `assistant` | full content-block handling (§4) |
| `AgentThoughtChunk` | `REASONING_MESSAGE_START/CONTENT/END` | full content-block handling (§4) |
| `ToolCall` (initial) | `TOOL_CALL_START` + `TOOL_CALL_ARGS` + `CUSTOM pocketcoder:tool` | read initial `Status`/`Content`; if already terminal → also `RESULT`+`END` (single-shot fix, §5) |
| `ToolCallUpdate` | `TOOL_CALL_ARGS`? + `RESULT`? + `END`? + `CUSTOM pocketcoder:tool` | args if new `rawInput`; result per §4.2; `END` on terminal status |
| `Plan` | `STATE_SNAPSHOT` `/pocketcoder/plan` | `{entries:[{content,priority,status}]}` — the todo checklist |
| `PlanUpdate` *(Unstable)* | `STATE_DELTA` `/pocketcoder/plan` | mutate entries |
| `PlanRemoved` *(Unstable)* | `STATE_DELTA` `/pocketcoder/plan` (remove) | |
| `CurrentModeUpdate` | `STATE_DELTA` `/pocketcoder/modes` `currentModeId` | agent-initiated mode switch (was dropped) |
| `ConfigOptionUpdate` | `STATE_SNAPSHOT` `/pocketcoder/config` | refreshed option set/values (was dropped) |
| `AvailableCommandsUpdate` | `STATE_SNAPSHOT` `/pocketcoder/commands` | `[{name,description,input?}]` — command palette |
| `SessionInfoUpdate` *(Unstable)* | `STATE_DELTA` `/pocketcoder/session_info` | title/info |
| *unknown / vendor / future* | `RAW` | never dropped (principle 1) |

Session-init responses (`NewSession`/`LoadSession`) seed `/pocketcoder/modes` and `/pocketcoder/config` from `Modes`/`ConfigOptions` (also previously discarded).

## 4. Complete content handling

### 4.1 `ContentBlock` (agent/user/thought chunks) — 4 variants
| variant | mapping |
|---|---|
| `Text` | text → `delta` |
| `Image` | `CUSTOM pocketcoder:media` `{messageId, kind:"image", mimeType, data, uri?}` |
| `Audio` | `CUSTOM pocketcoder:media` `{messageId, kind:"audio", mimeType, data}` |
| `ResourceLink` | `CUSTOM pocketcoder:media` `{messageId, kind:"resource_link", name, uri, mimeType?, size?}` |

A shared `renderContent` helper is the single place content is decoded — no variant falls through.

### 4.2 `ToolCallContent` (tool results) — 3 variants
| variant | mapping |
|---|---|
| `Content` (text) | `TOOL_CALL_RESULT.content` = text |
| `Diff` | `TOOL_CALL_RESULT.content` = unified-diff text (fallback) **+** `CUSTOM pocketcoder:diff` `{toolCallId, path, oldText?, newText}` (structured, for the diff viewer) |
| `Terminal` | `TOOL_CALL_RESULT.content` = terminal text if embedded **+** `CUSTOM pocketcoder:terminal` `{toolCallId, terminalId, type}` |

### 4.3 Tool metadata → `CUSTOM pocketcoder:tool`
Emitted alongside `TOOL_CALL_START` and re-emitted on status change:
```json
{ "toolCallId":"…", "title":"…",
  "kind":"read|edit|delete|move|search|execute|think|fetch|switch_mode|other",
  "status":"pending|in_progress|completed|failed",
  "locations":[ {"path":"…","line":123} ] }
```
Carries `Kind` (icon/type rendering), `Status` (spinner/badges incl. intermediate `pending`/`in_progress`), and `Locations` (jump-to-file / diff anchor) — all previously dropped.

## 5. Correctness fixes (regression tests required)

1. **Single-shot completed `ToolCall`:** read the initial `ToolCall.Status` and `ToolCall.Content`. If status is terminal, emit `START`+`ARGS`+`RESULT`+`END` in one pass instead of leaking an open tool with no result.
2. **Non-fatal updates:** `Update` returns `(events, err)` where `err` is reserved for fatal only; unmappable/partial updates log + emit `RAW` and continue. The coordinator's `SessionUpdate` handler must **not** abort the turn on a soft translation miss.
3. **User-message replay:** `UserMessageChunk` handling (§3) so `GET …/stream` history shows both sides.
4. **Multimodal never-drop:** image/audio/resource surface via `pocketcoder:media` (§4.1) rather than vanishing.
5. **Intermediate tool status:** surfaced via `pocketcoder:tool.status` (§4.3).

## 6. State projection + `Snapshot()`

The Bridge maintains a **current-state model** for the `/pocketcoder/*` STATE namespaces (`permission`, `elicitation`, `modes`, `config`, `plan`, `commands`, `session_info`). It exposes:
- `Update(SessionNotification) ([]events.Event, error)` — emits standard + STATE_DELTA + CUSTOM.
- `Snapshot() []events.Event` — a `STATE_SNAPSHOT` per non-empty namespace, for a **late-joining subscriber** (the run hub calls this on attach; hub logic is the c1↔c2 spec's concern — this unit just provides the projection).
- `Started()` / `Finished()` — unchanged lifecycle (still correct).

STATE_DELTA remains the wire format for incremental changes; `Snapshot()` gives new subscribers the baseline so cursors/replay stay cheap (no Goose round-trip for ambient state).

## 7. Module structure

- `internal/agent/agui/bridge.go` — the Bridge: text/reasoning/tool boundary machine + `Update`/`Snapshot`/`Started`/`Finished`. (Refactor of today's file.)
- `internal/agent/agui/content.go` — `renderContent` (all `ContentBlock` variants) + `renderToolContent` (all `ToolCallContent` variants). Single decode point.
- `internal/agent/agui/state.go` — the `/pocketcoder/*` state projection: apply an update, produce `STATE_DELTA`, produce `STATE_SNAPSHOT`.
- `internal/agent/agui/custom.go` — constructors for the `pocketcoder:*` `CUSTOM` events (`tool`, `diff`, `terminal`, `media`, and the `RAW` fallback).
- `internal/agent/agui/bridge_test.go` (+ `content_test.go`, `state_test.go`) — golden-sequence tests.

Small, focused files; each independently testable.

## 8. Testing (TDD)

Table-driven golden tests — for each ACP update, assert the exact ordered `[]events.Event`:
- Every `SessionUpdate` variant in §3 (incl. `RAW` for a synthetic unknown/vendor update).
- Content variants: text / image / audio / resource_link (§4.1).
- Tool-content variants: content / **diff** / **terminal** (§4.2).
- Correctness: **single-shot completed tool call**; malformed update (missing `toolCallId`) → `RAW`, **turn not aborted**; `UserMessageChunk` → user text.
- Boundary interleavings: text→tool→text; reasoning→text; concurrent open tools closed at `Finished()`.
- Plan lifecycle (`Plan` snapshot → `PlanUpdate` delta → `PlanRemoved`); mode/config/commands updates → correct STATE.
- `Snapshot()` after a sequence returns a correct per-namespace `STATE_SNAPSHOT`.

## 9. Consequences for the contract & coordinator

- **Contract spec (`2026-07-19-c1-flutter-contract-spec.md`):** the down-channel catalog gains `/pocketcoder/plan`, `/pocketcoder/commands`, `/pocketcoder/session_info` STATE and the `pocketcoder:{tool,diff,terminal,media}` + `RAW` CUSTOM events. Update §5 there once this lands.
- **Coordinator:** its `sessionClient.SessionUpdate` must treat soft `Update` misses as non-fatal (§5.2), and it must feed session-init `Modes`/`ConfigOptions` into the Bridge, and call `Snapshot()` for late subscribers (the latter is wired in the c1↔c2 bridge spec).

## 10. Open items

- **`pocketcoder:media` transport for large images:** inline base64 vs. a fetch URL. Lean fetch-URL for large payloads to keep the SSE stream light — decide in the plan.
- **`Diff` fallback text:** generate a real unified diff (needs a tiny diff lib or a naive line diff) vs. just shipping `{oldText,newText}` and letting Flutter render. Lean: ship structured, minimal/no server-side diff text.
- **Unstable-variant churn:** `PlanUpdate`/`PlanRemoved`/`SessionInfoUpdate` are Unstable ACP; pin behavior to the Goose image's actual emissions and gate on presence.
