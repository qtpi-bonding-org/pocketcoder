# Flutter Chat UI Migration Design

**Status:** Approved design, execution deferred — the ACP→AG-UI field-drop bug-fix pass (see companion note below) runs first. This spec is written now so the design isn't lost in the meantime.

## Goal

Replace the hand-rolled `_ConversationList`/`_ChatMessageTile`/`_ToolCallCard` widgets in `client/packages/pocketcoder_flutter/lib/presentation/chat/chat_screen.dart` with the `flyerhq/flutter_chat_ui` package (v2, the `flyer_chat_*` family), using it as far as it reasonably goes: message list, streaming text, and inline human-in-the-loop (permission/elicitation) surfaces.

## Why

- `flutter_chat_ui`'s `Builders.customMessageBuilder` + `Message.custom`'s free-form `metadata` map is a genuine fit for tool-call cards and inline approval UI — not a workaround, the same mechanism the library uses for its own non-bubble "system message" type.
- `flyer_chat_text_stream_message` + `TextStreamMessage` handles token-by-token streaming animation, scroll-follow, and in-place message growth — all things `chat_screen.dart` currently hand-rolls or (in the streaming case) doesn't do at all.
- `ChatController.setMessages(List<Message>)` replaces the whole message list per call and internally diffs/animates the change (confirmed by reading `InMemoryChatController.setMessages` in the package source) — this maps directly onto how `ChatCubit` already emits a full `Conversation` snapshot on every change. No new persistence or state-management layer needed.

## Surprising finding along the way

Today, `conversation_reducer.dart` only appends a `ChatMessage` to `Conversation.messages` on the message's `*_END` event — the in-progress text lives in a private `StringBuffer` (`_openText`) that's never exposed. So despite AG-UI delivering token-level `TEXT_MESSAGE_CONTENT` deltas, **no streaming is visible today** — a reply just pops in complete. This migration is also where that gets fixed (see Reducer changes below).

## Architecture / Data flow

```
AG-UI SSE events → agent_chat_repository.watch() → reduce() → Conversation{timeline: List<TimelineItem>}
   → ChatCubit emits ChatState → chat_screen BlocBuilder
   → timelineToMessages(state.conversation.timeline) → List<flyer.Message>
   → InMemoryChatController.setMessages(...) → flyer Chat widget renders/animates the diff
```

Cubits are unchanged in shape and responsibility — `ChatCubit`, `PermissionCubit`, `ElicitationCubit`, `SessionControlsCubit` all keep working exactly as they do today. This is purely a rendering-layer swap plus one reducer-shape change to support it.

## Component changes

### 1. Go bridge (`services/pocketbase/internal/agent/agui/bridge.go`, `internal/agent/coordinator/run.go`)

Thread `req.ToolCall.ToolCallId` (from ACP's `RequestPermissionRequest.ToolCall`, a field `run.go`'s `RequestPermission` currently reads `req.Options`/`req.SessionId` from but drops `req.ToolCall` entirely — `run.go:405-419`) through `Bridge.PermissionPending()` so the `/pocketcoder/permission` STATE_DELTA payload becomes `{requestId, status, options, toolCallId}` (was `{requestId, status, options}`, `bridge.go:282`). Additive field, backward compatible.

### 2. Reducer (`client/packages/pocketcoder_flutter/lib/domain/agent/conversation_reducer.dart`, `conversation.dart`)

Replace the current two flat lists (`messages: List<ChatMessage>`, `toolCalls: List<ToolCall>`) plus the separate `sessionState.permission`/`sessionState.elicitation` slots with **one ordered timeline**:

```dart
enum TimelineItemKind { text, reasoning, textStream, toolCall, permission, elicitation }

@freezed
sealed class TimelineItem with _$TimelineItem {
  const factory TimelineItem.text({required String id, required String role, required String text, required ChatMessageKind kind}) = _TextItem;
  const factory TimelineItem.textStream({required String id, required String role, required String partialText}) = _TextStreamItem;
  const factory TimelineItem.toolCall({required String id, required String name, required String args, String? result}) = _ToolCallItem;
  const factory TimelineItem.permission({required String requestId, required String? toolCallId, required Map<String, dynamic> raw}) = _PermissionItem;
  const factory TimelineItem.elicitation({required String requestId, required Map<String, dynamic> raw}) = _ElicitationItem;
}
```

- Items append in true event order (fixes today's "all messages, then all tool calls" display bug).
- The still-open text/reasoning message is surfaced as a `TimelineItem.textStream` entry (using its partial `StringBuffer` content) instead of being invisible until `*_END`; it's replaced by the equivalent `TimelineItem.text` (same id) once the end event lands.
- Permission/elicitation items are positioned immediately after the `TimelineItem.toolCall` matching their `toolCallId` (once the Go fix above lands); if no match is found (e.g. `toolCallId` absent), append at the end — same behavior as today, just as a defined fallback rather than an accident.
- `Conversation` becomes `Conversation({required List<TimelineItem> timeline})`; `sessionState` keeps `modes`/`config`/`plan`/`title` (unchanged — those aren't per-message, they're session-wide chrome handled by `ModeSwitcher`/`ConfigPicker`/`PlanPanel`, which stay as separate widgets, not timeline items).

### 3. New adapter (`client/packages/pocketcoder_flutter/lib/presentation/chat/timeline_to_messages.dart`)

Pure function, `List<TimelineItem> → List<flyer_chat_core.Message>`:

| `TimelineItem` | `flyer.Message` | Notes |
|---|---|---|
| `text` | `TextMessage` | `authorId` from `role` (`'user'` vs agent's fixed id) |
| `textStream` | `TextStreamMessage` | same `id` as the eventual `text` replacement |
| `toolCall` | `CustomMessage` | `metadata: {kind: 'toolCall', name, args, result}` |
| `permission` | `CustomMessage` | `metadata: {kind: 'permission', requestId, options, status}` |
| `elicitation` | `CustomMessage` | `metadata: {kind: 'elicitation', requestId, ...raw}` |

### 4. `chat_screen.dart`

- Add `dependencies`: `flutter_chat_core`, `flutter_chat_ui`, `flyer_chat_text_stream_message` to `pubspec.yaml`.
- Replace `_ConversationList`/`_ChatMessageTile`/`_ToolCallCard` with flyer's `Chat` widget, backed by an `InMemoryChatController` that gets `setMessages(timelineToMessages(state.conversation.timeline))` called on every `BlocBuilder` rebuild.
- `Builders`:
  - `textStreamMessageBuilder`: styled to match current `_ChatMessageTile` (COMMANDER/POCO/THINKING label + terminal color scheme).
  - `customMessageBuilder`: branches on `metadata['kind']` — `toolCall` renders what `_ToolCallCard` renders today; `permission` renders what `PermissionPrompt` renders today (reading `PermissionCubit` via `context.read<>()` for authorize/deny); `elicitation` likewise via `ElicitationCubit`.
  - `composerBuilder`: wraps the existing `_SimpleInput` unchanged (no visual/behavioral change to the input bar).
- `PlanPanel`, `ModeSwitcher`, `ConfigPicker` remain exactly where they are today (outside/around the `Chat` widget) — they're session-wide, not per-message.
- `PermissionPrompt`/`ElicitationForm` standalone widgets are deleted; their rendering logic moves into the `customMessageBuilder` branches above.

## Error handling / edge cases

- Permission/elicitation with no correlatable tool call: append-at-end fallback (defined behavior, matches today).
- Cold-replay (`pocketcoder:sync` replace marker) already resets the reducer's accumulator wholesale (`_ConversationBuilder.reset()`) — a full-timeline rebuild is a natural fit since `ChatController.setMessages` already expects "whole list, replace" semantics.
- `TextStreamMessage`→`TextMessage` id reuse means no special update path is needed; `setMessages` simply reflects "yesterday's stream item is gone, today's text item has the same id."

## Testing

- `conversation_reducer_test.dart` (extend existing): timeline ordering, permission-after-its-toolCall positioning, in-progress streaming item present before `*_END`, fallback positioning when `toolCallId` is absent.
- New `timeline_to_messages_test.dart`: one test per `TimelineItem` variant → `Message` variant mapping.
- Go: extend `bridge_test.go`'s existing permission test to assert `toolCallId` round-trips into the STATE_DELTA payload.
- Manual: `tests/agent-c1/run.sh` (live acceptance suite) plus a manual phone/simulator pass watching a real tool-call-gated permission render inline and resolve.

## Explicitly out of scope

- Elicitation URL-mode UI: the Go bridge now forwards `url`/`message` correctly for URL-mode elicitations (fixed in the pre-migration bug-fix pass), but `ElicitationCard` still only renders schema-based forms. A "here's a link" rendering is a small standalone follow-up, not part of this migration.

## Status

The 5 other ACP→AG-UI field-drop bugs found by the audit (elicitation `Url` variant, config `Select.Options`, embedded `ContentBlock.Resource`, tool-result media, `AvailableCommand.Input.Hint`) were fixed in a Go-only pass before this migration started, per the project decision to land the backend bug fixes first. This migration itself (`TimelineItem` domain model, reducer rewrite, `flutter_chat_ui` adoption, inline permission/elicitation cards, token-level streaming) is implemented and committed; see `docs/superpowers/plans/2026-07-21-flutter-chat-ui-migration.md` for the task-by-task record. Automated verification (analyzer + full test suite) is green; a manual browser walkthrough is still pending.
