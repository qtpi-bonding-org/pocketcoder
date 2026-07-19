# Flutter AG-UI Rebuild — DRAFT Spec

**Date:** 2026-07-18
**Status:** DRAFT — capture only. Needs a full brainstorming pass before it earns an implementation plan. Do NOT execute from this document.
**Superseded in part / re-sequenced (2026-07-19):** brainstorming this rebuild revealed the c1↔c2 bridge is a thin happy-path that must be made robust *first*. The Flutter-facing wire contract is now specced separately in **`2026-07-19-c1-flutter-contract-spec.md`** (the acceptance target), and the foundation is the **Robust c1↔c2 ACP bridge** (to be specced next). Build order is now: robust c1↔c2 bridge → (this) Flutter client on top. Treat this doc as the client-side notes; the contract + open questions live in the newer specs.
**Depends on:** Legacy Runtime Prune (`2026-07-18-legacy-runtime-prune-design.md`) landing first. The pruned backend drops `messages`/`permissions`/`acp_terminals` and the legacy `chats` fields, which breaks the current Flutter client — this rebuild is what makes the app work again.

## Why this exists

The prune leaves the Flutter package pointed at a backend that no longer exists. The client today streams turns over **PocketBase realtime + a Drift offline cache**, reads history from the deleted **`messages`** collection, and does HITL over the deleted **`permissions`** collection. The new backend speaks **AG-UI over SSE** and treats **Goose (c2) as the sole system of record** for turn history. This rebuild re-points the client at that surface.

## Current state (grounded)

**Package layout** (`client/`):
- `packages/pocketcoder_flutter/` — main client: all chat/HITL/agent surface.
- `packages/app/` — onboarding/auth/deployment cubits + screens only.
- `apps/app/` (`pocketcoder_app`) — runnable shell; `lib/` is just `main.dart`.

**Stack:** Cubits only (flutter_bloc 8.1.3, `AppCubit<T>`/`cubit_ui_flow`), injectable/GetIt DI, freezed models. No riverpod, no bloc-events.

**Current transport (all to be replaced):**
- `infrastructure/communication/chat_repository.dart` — **cold pipe** (`MessageDao.watch` = Drift `watchRecords` on `messages`) + **hot pipe** (`pb.realtime.subscribe('chats:$chatId')` parsing `text_delta`/`tool_status`/`message_snapshot`/`message_complete`/`message_error`).
- `infrastructure/communication/communication_daos.dart` — `ChatDao`/`MessageDao`/`SandboxAgentDao`.
- `infrastructure/hitl/hitl_daos.dart` + `hitl_repository.dart` — `PermissionDao`/`QuestionDao`/`ToolPermissionDao`; `watchPending` (permissions `status="draft"`), `authorize`/`deny` (writes `permissions.status`).
- `application/chat/chat_cubit.dart` — wires cold+hot into `ChatState`; `sendMessage` writes a `role:user` record into `messages` (no run endpoint call — backend reacts to the DB insert). Uses `chat.aiEngineSessionId` (deleted field).
- `application/chat/chat_state.dart` — `HotPipeEvent` union (`textDelta`/`toolStatus`/`snapshot`/`complete`/`error`).
- `application/permission/permission_cubit.dart` — `watchChat` → `watchPending`, `authorize`/`deny`.
- `presentation/chat/chat_screen.dart` — `BlocBuilder<ChatCubit>` + `BlocListener` triggering `PermissionCubit`/`QuestionCubit`; renders HITL via `presentation/core/widgets/permission_prompt.dart`.
- Empty dirs already scaffolded: `infrastructure/realtime/`, `infrastructure/chat/`, `infrastructure/permission/`.

**Backend AG-UI surface that already exists** (`services/pocketbase/internal/api/agent.go`, `RegisterAgentApi`, all `RequireAuth`, `Content-Type: text/event-stream`):
- `POST /api/pocketcoder/chats/{chatId}/runs` — body `{"prompt": string}`; emits AG-UI events `RUN_STARTED … RUN_FINISHED`, `RUN_ERROR` (code `goose_unavailable`); drives one Goose ACP turn; persists a `goose_sessions` row.
- `GET  /api/pocketcoder/chats/{chatId}/events` — **bounded replay** of a chat's Goose session (not a live subscription).
- `POST /api/pocketcoder/chats/{chatId}/cancel` — cancel active run.
- `POST /api/pocketcoder/chats/{chatId}/approvals/{approvalId}` — body `{"optionId": string}` — the AG-UI replacement for the `permissions`-collection HITL write.

**Model pipeline:** `scripts/generate_models.py` reads `assets/pb_schema.json` → `lib/domain/models/*.dart` + `collections.dart`; then `dart run build_runner build`. Models to delete after prune: `message.dart`, `permission.dart`, `acp_terminal.dart` (+ freezed/g trios). `goose_sessions` is **not** in `pb_schema.json` yet — schema must be re-exported and models regenerated.

## What we know we want

- A **single SSE consumer** behind `IChatRepository` that replaces the cold/hot split — consumes AG-UI events from `POST .../runs` and renders the live turn.
- `sendMessage` calls `POST .../runs` directly (no more DB-insert-and-hope).
- HITL routed through `POST .../approvals/{approvalId}` instead of writing `permissions`.
- History via `GET .../events` replay on chat open (Goose owns history; no local `messages` mirror).
- Delete the dead surface: `MessageDao`, `PermissionDao`, `permission_cubit`'s collection watch, the `messages`/`permissions`/`acp_terminals` models, and the `chat.aiEngineSessionId` usages. Regenerate models from the pruned schema.

## Open questions (resolve in brainstorming)

1. **Offline cache:** keep `pocketbase_drift` for chat *list*/ownership (still PB-owned) but drop it for *turn content*? Or go fully online for chats? What's the offline story when Goose owns history and only exposes bounded replay?
2. **Live vs replay:** `GET .../events` is bounded replay, not a live subscription. Is a reconnect during an in-flight run supposed to resume the live `runs` stream, re-hit `events`, or both? What happens to a turn if the app backgrounds mid-stream?
3. **AG-UI event → UI model mapping:** define the full AG-UI event set the backend emits (tool calls, text deltas, thinking, snapshots) and the Dart state shape that replaces `HotPipeEvent`. Is there an AG-UI Dart client to reuse, or hand-roll an `EventSource`/SSE parser (none exists in the client today)?
4. **HITL/approvals UX:** how does an approval request arrive to the client — inline in the `runs` SSE stream as an AG-UI event, or a separate channel? Does `approvals/{approvalId}` block the run until answered?
5. **`questions` collection & `tool_permissions`:** `questions` (ACP "ask") and persistent `tool_permissions` allow/deny rules were NOT dropped by the prune. Do they survive as-is, fold into the approvals flow, or wait for the agent-def revamp?
6. **Terminal:** `SshTerminalCubit` is direct SSH (dartssh2, port 2222), unrelated to `acp_terminals`. Untouched by this rebuild — confirm.
7. **Scope of the two secondary packages** (`packages/app`, `apps/app`) — do they need any change, or is this purely `pocketcoder_flutter`?

## Non-goals

- Backend changes to the AG-UI endpoints (they exist; this is client-side).
- Agent-definition config UI (separate revamp).
- Design-system / visual redesign — re-point transport, keep the UI.

## Next step

Full `superpowers:brainstorming` pass to close the open questions, then `writing-plans`. This draft is the starting context for that session, not an approved spec.
