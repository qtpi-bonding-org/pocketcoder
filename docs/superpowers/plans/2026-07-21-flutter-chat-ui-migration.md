# Flutter Chat UI Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `chat_screen.dart`'s hand-rolled message list with `flyerhq/flutter_chat_ui` (the `flyer_chat_*` v2 family), rendering an ordered conversation timeline with inline tool calls and inline permission/elicitation approval cards, plus real token-level text streaming.

**Architecture:** `conversation_reducer.dart` folds the AG-UI event log into one ordered `List<TimelineItem>` (text/reasoning, in-progress streaming text, tool calls, permission, elicitation) instead of today's two flat lists. A pure adapter (`timeline_to_messages.dart`) projects that into `flutter_chat_core`'s `Message` model on every Cubit emit; `InMemoryChatController.setMessages(...)` takes it from there (it diffs/animates internally). `Chat`'s custom builders render each message kind; permission/elicitation builders defer all interactivity to the existing `PermissionCubit`/`ElicitationCubit` unchanged — this is a rendering-layer swap, not a state-management change.

**Tech Stack:** `flutter_chat_core: ^2.9.0`, `flutter_chat_ui: ^2.11.1`, `flyer_chat_text_stream_message: ^2.3.0` (new deps); existing `flutter_bloc`, `freezed`, `injectable`, `cubit_ui_flow` (unchanged).

## Global Constraints

- Never use `!` (null-assertion) — see `client/CLAUDE.md`. Use `?.`/`??`/early-return.
- Cubits only, all extending `AppCubit<T>`; states extend `IUiFlowState` with `@freezed` and `status`/`error` fields (`client/CLAUDE.md`). This plan does not add or change any Cubit.
- Every new/changed `.dart` file with generated code needs `dart run build_runner build --delete-conflicting-outputs` from `client/packages/pocketcoder_flutter` (`client/CLAUDE.md`).
- Never hardcode user-facing strings — reuse existing `context.l10n.*` keys; this plan introduces no new user-facing strings, so no `.arb` changes are needed.
- Design doc: `docs/superpowers/specs/2026-07-21-flutter-chat-ui-migration-design.md`. This plan refines two points beyond what that doc spelled out (both explained inline in Task 2 and Task 6): tool calls must enter the timeline on `ToolCallStartEvent` (not `ToolCallEndEvent`) for permission correlation to actually work, and `flyer_chat_text_stream_message`'s `StreamState` is supplied by the caller per-build (no external "stream manager" class needed — it's a pure projection of the timeline, same as everything else here).
- The Go-side `toolCallId` fix this design depends on is already merged (commit `4909c169d`, prior work). No backend changes in this plan.
- Elicitation URL-mode UI (a "here's a link" card) is explicitly **out of scope** for this migration — `elicitation_card.dart` (Task 9) is a verbatim extraction of today's schema-form-only `ElicitationForm`, which has no `mode == 'url'` branch today and gets none here. Flag this to the user after the plan is delivered; it's a separate small feature, not a migration blocker.

---

### Task 1: Add `TimelineItem` and restructure `Conversation`

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/domain/agent/conversation.dart`

**Interfaces:**
- Produces: `TimelineItem` sealed class (variants `text`, `textStream`, `toolCall`, `permission`, `elicitation`) and `Conversation.timeline: List<TimelineItem>` — consumed by Task 2 (reducer), Task 3 (tests), Task 5 (adapter).
- `ChatMessageKind` (existing `{text, reasoning}` enum) is reused unchanged for `TimelineItem.text.kind`.
- `SessionState` is unchanged (`permission`/`elicitation`/`modes`/`config`/`plan`/`title` all stay) — `PermissionCubit`/`ElicitationCubit` keep reading `sessionState.permission`/`.elicitation` exactly as today.
- `Conversation.messages`/`Conversation.toolCalls` are **removed** (replaced by `timeline`). This is a breaking change to `Conversation`'s shape — every call site is fixed in later tasks.

- [x] **Step 1: Replace the message/tool-call model with `TimelineItem` and rewrite `Conversation`**

Edit `client/packages/pocketcoder_flutter/lib/domain/agent/conversation.dart`. Replace the `ChatMessage`/`ToolCall`/`Conversation` sections (keep `ChatMessageKind` and `SessionState` as-is) with:

```dart
/// One item in the ordered conversation timeline: text/reasoning prose, an
/// in-progress streaming reply, a tool invocation, or an inline
/// permission/elicitation card. Built by `reduce()` (conversation_reducer.dart)
/// in true chronological order — replaces the old flat `messages`/`toolCalls`
/// lists, which lost ordering between the two.
@freezed
sealed class TimelineItem with _$TimelineItem {
  /// A completed message: concatenation of every `*_CONTENT` delta between
  /// a message's `*_START` and `*_END`.
  const factory TimelineItem.text({
    required String id,
    required ChatMessageKind kind,
    required String role,
    required String text,
  }) = TextTimelineItem;

  /// A still-open text message: `text` is the partial content accumulated
  /// so far (grows on every `TEXT_MESSAGE_CONTENT` delta). Replaced in place
  /// by a `TimelineItem.text` (same `id`) once `TEXT_MESSAGE_END` arrives.
  const factory TimelineItem.textStream({
    required String id,
    required String role,
    required String text,
  }) = TextStreamTimelineItem;

  /// One tool invocation. Enters the timeline on `TOOL_CALL_START` (not
  /// `_END` — a pending permission needs a real timeline position to
  /// correlate against, and permission is requested *before* the tool call
  /// ends). `args`/`result` fill in as `TOOL_CALL_ARGS`/`_RESULT` arrive;
  /// an empty `args`/`null` result just means "still running", same as
  /// today's `_ToolCallCard`'s conditional rendering.
  const factory TimelineItem.toolCall({
    required String id,
    required String name,
    @Default('') String args,
    String? result,
  }) = ToolCallTimelineItem;

  /// A pending permission, positioned right after the `toolCall` item it
  /// gates (correlated by `toolCallId` on the STATE_DELTA payload — see
  /// `services/pocketbase/internal/agent/agui/bridge.go`'s `PermissionPending`).
  /// Carries no payload: the actual pending-permission data + actions still
  /// flow through `PermissionCubit`/`PermissionState.permission` unchanged;
  /// this is purely a "render the permission card here" timeline marker.
  const factory TimelineItem.permission({
    required String requestId,
  }) = PermissionTimelineItem;

  /// A pending elicitation. No tool-call correlation exists on the wire for
  /// elicitation (unlike permission), so this always appends at the current
  /// end of the timeline. Same "marker only" shape as `permission` —
  /// `ElicitationCubit`/`ElicitationState.elicitation` still own the data.
  const factory TimelineItem.elicitation({
    required String requestId,
  }) = ElicitationTimelineItem;
}

/// The full reduced view of a chat's AG-UI event stream: the ordered
/// timeline plus the ambient session state. `reduce()` (in
/// conversation_reducer.dart) is the only producer.
@freezed
sealed class Conversation with _$Conversation {
  const factory Conversation({
    @Default(<TimelineItem>[]) List<TimelineItem> timeline,
    @Default(SessionState.empty) SessionState sessionState,
  }) = _Conversation;

  const Conversation._();

  static const empty = Conversation();
}
```

- [x] **Step 2: Regenerate freezed code**

```bash
cd client/packages/pocketcoder_flutter
dart run build_runner build --delete-conflicting-outputs
```

Expected: `conversation.freezed.dart` regenerates with `TimelineItem`/`TextTimelineItem`/etc. and the new `Conversation` shape. The build will report errors in every file still referencing `Conversation.messages`/`.toolCalls`/`ChatMessage`/`ToolCall` (the reducer, `chat_screen.dart`, and the reducer test) — expected at this point; Tasks 2–3 and 10 fix them. Do not attempt to fix those files in this task.

- [x] **Step 3: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/domain/agent/conversation.dart client/packages/pocketcoder_flutter/lib/domain/agent/conversation.freezed.dart
git commit -m "feat(flutter): add TimelineItem, replace Conversation's flat message/tool lists"
```

---

### Task 2: Rewrite `conversation_reducer.dart` to build the ordered timeline

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/domain/agent/conversation_reducer.dart`

**Interfaces:**
- Consumes: `TimelineItem` variants from Task 1.
- Produces: `Conversation build()` returning `Conversation(timeline: ..., sessionState: ...)`. `_sessionState()` (private) is unchanged — still populates `permission`/`elicitation`/`modes`/`config`/`plan`/`title` from the same `_pocketcoder` accumulator, so `PermissionCubit`/`ElicitationCubit`/`ModeSwitcher`/`ConfigPicker`/`PlanPanel` need no changes.

- [x] **Step 1: Replace `_ConversationBuilder` with the timeline-tracking version**

Edit `client/packages/pocketcoder_flutter/lib/domain/agent/conversation_reducer.dart`. Keep the top-level `reduce()` function and the doc comment unchanged. Replace `_OpenMessage`, `_OpenTool`, and `_ConversationBuilder` with:

```dart
class _OpenMessage {
  _OpenMessage(this.role);
  final String role;
  final StringBuffer text = StringBuffer();
}

class _ConversationBuilder {
  final List<TimelineItem> _timeline = [];
  final Map<String, _OpenMessage> _openText = {};
  final Map<String, int> _openTextIndex = {};
  final Map<String, _OpenMessage> _openReasoning = {};
  final Map<String, int> _toolTimelineIndex = {};
  final Map<String, dynamic> _pocketcoder = {};

  void reset() {
    _timeline.clear();
    _openText.clear();
    _openTextIndex.clear();
    _openReasoning.clear();
    _toolTimelineIndex.clear();
    _pocketcoder.clear();
  }

  void apply(ag_ui.BaseEvent event) {
    switch (event) {
      case ag_ui.TextMessageStartEvent():
        final open = _OpenMessage(event.role.value);
        _openText[event.messageId] = open;
        _insertTimelineItem(_timeline.length,
            TimelineItem.textStream(id: event.messageId, role: open.role, text: ''));
        _openTextIndex[event.messageId] = _timeline.length - 1;
      case ag_ui.TextMessageContentEvent():
        var open = _openText[event.messageId];
        if (open == null) {
          open = _OpenMessage('assistant');
          _openText[event.messageId] = open;
          _insertTimelineItem(_timeline.length,
              TimelineItem.textStream(id: event.messageId, role: open.role, text: ''));
          _openTextIndex[event.messageId] = _timeline.length - 1;
        }
        open.text.write(event.delta);
        final idx = _openTextIndex[event.messageId];
        if (idx != null) {
          _timeline[idx] = TimelineItem.textStream(
              id: event.messageId, role: open.role, text: open.text.toString());
        }
      case ag_ui.TextMessageEndEvent():
        final open = _openText.remove(event.messageId);
        final idx = _openTextIndex.remove(event.messageId);
        if (open != null && idx != null) {
          _timeline[idx] = TimelineItem.text(
            id: event.messageId,
            kind: ChatMessageKind.text,
            role: open.role,
            text: open.text.toString(),
          );
        }

      case ag_ui.ReasoningMessageStartEvent():
        _openReasoning[event.messageId] = _OpenMessage(event.role.value);
      case ag_ui.ReasoningMessageContentEvent():
        _openReasoning
            .putIfAbsent(event.messageId, () => _OpenMessage('assistant'))
            .text
            .write(event.delta);
      case ag_ui.ReasoningMessageEndEvent():
        final open = _openReasoning.remove(event.messageId);
        if (open != null) {
          _insertTimelineItem(
            _timeline.length,
            TimelineItem.text(
              id: event.messageId,
              kind: ChatMessageKind.reasoning,
              role: open.role,
              text: open.text.toString(),
            ),
          );
        }

      case ag_ui.ToolCallStartEvent():
        _insertTimelineItem(_timeline.length,
            TimelineItem.toolCall(id: event.toolCallId, name: event.toolCallName));
        _toolTimelineIndex[event.toolCallId] = _timeline.length - 1;
      case ag_ui.ToolCallArgsEvent():
        _updateTool(event.toolCallId,
            (t) => t.copyWith(args: t.args + event.delta));
      case ag_ui.ToolCallResultEvent():
        _updateTool(event.toolCallId, (t) => t.copyWith(result: event.content));
      case ag_ui.ToolCallEndEvent():
        // No-op: the timeline entry already carries the latest args/result
        // from the ARGS/RESULT updates above. v1 has no separate "ended"
        // flag — the widget layer treats "has a result" as terminal, same
        // as today's _ToolCallCard.
        break;

      case ag_ui.StateSnapshotEvent():
        final snapshot = event.snapshot;
        _pocketcoder.clear();
        if (snapshot is Map) {
          final pocketcoder = snapshot['pocketcoder'];
          _pocketcoder.addAll(
              pocketcoder is Map ? Map<String, dynamic>.from(pocketcoder) : {});
        }
        _syncPermission();
        _syncElicitation();
      case ag_ui.StateDeltaEvent():
        for (final op in event.delta) {
          _applyPatch(op);
        }

      default:
        // RUN_*, CUSTOM (non-marker), other event kinds carry nothing the
        // v1 reducer surfaces — ignored rather than guessed at.
        break;
    }
  }

  /// Applies `update` to the tracked tool-call timeline entry for `id`. A
  /// tool id with no tracked index (ARGS/RESULT arriving without a prior
  /// START in this reduce pass — shouldn't happen, but never silently drop
  /// data) gets a fresh entry appended rather than being discarded.
  void _updateTool(String id, ToolCallTimelineItem Function(ToolCallTimelineItem) update) {
    var idx = _toolTimelineIndex[id];
    if (idx == null) {
      _insertTimelineItem(_timeline.length, TimelineItem.toolCall(id: id, name: ''));
      idx = _timeline.length - 1;
      _toolTimelineIndex[id] = idx;
    }
    final current = _timeline[idx];
    if (current is ToolCallTimelineItem) {
      _timeline[idx] = update(current);
    }
  }

  /// Inserts `item` at `index` and shifts every tracked timeline index
  /// (`_toolTimelineIndex`, `_openTextIndex`) that points at or after the
  /// insertion point, so in-place updates (`_updateTool`, streaming text
  /// content) keep hitting the right slot after a permission/elicitation
  /// item gets inserted mid-timeline.
  void _insertTimelineItem(int index, TimelineItem item) {
    _timeline.insert(index, item);
    _toolTimelineIndex.updateAll((_, i) => i >= index ? i + 1 : i);
    _openTextIndex.updateAll((_, i) => i >= index ? i + 1 : i);
  }

  /// Removes every timeline item matching `test`, shifting tracked indices
  /// down to match (mirror of `_insertTimelineItem`).
  void _removeTimelineItemsWhere(bool Function(TimelineItem) test) {
    for (var i = _timeline.length - 1; i >= 0; i--) {
      if (test(_timeline[i])) {
        _timeline.removeAt(i);
        _toolTimelineIndex.updateAll((_, v) => v > i ? v - 1 : v);
        _openTextIndex.updateAll((_, v) => v > i ? v - 1 : v);
      }
    }
  }

  /// Re-derives the single permission timeline entry (if any) from
  /// `_pocketcoder['permission']`: drop any existing one, then if a
  /// permission is pending, insert a fresh marker right after the tool call
  /// it names via `toolCallId` (falls back to append-at-end if that field
  /// is absent or doesn't match any tracked tool call).
  void _syncPermission() {
    _removeTimelineItemsWhere((item) => item is PermissionTimelineItem);
    final permission = _pocketcoder['permission'];
    if (permission is! Map) return;
    final requestId = permission['requestId'];
    if (requestId is! String) return;
    final toolCallId = permission['toolCallId'];
    final toolIdx = toolCallId is String ? _toolTimelineIndex[toolCallId] : null;
    _insertTimelineItem(
      toolIdx != null ? toolIdx + 1 : _timeline.length,
      TimelineItem.permission(requestId: requestId),
    );
  }

  /// Same as `_syncPermission` for elicitation, minus correlation: ACP's
  /// elicitation payload carries no tool-call id, so this always appends at
  /// the current end of the timeline.
  void _syncElicitation() {
    _removeTimelineItemsWhere((item) => item is ElicitationTimelineItem);
    final elicitation = _pocketcoder['elicitation'];
    if (elicitation is! Map) return;
    final requestId = elicitation['elicitationId'];
    if (requestId is! String) return;
    _insertTimelineItem(_timeline.length, TimelineItem.elicitation(requestId: requestId));
  }

  /// Applies one RFC 6902-shaped op (as emitted by the Go bridge: only
  /// `add`/`remove`, on either `/pocketcoder/<ns>` or
  /// `/pocketcoder/<ns>/<key>`) to the accumulated state map. A sub-path
  /// patch against an absent parent creates the parent rather than
  /// throwing (guards the Task 3 fix: modes' currentModeId sub-patch must
  /// not require availableModes to already exist).
  void _applyPatch(Map<String, dynamic> op) {
    final path = op['path'] as String?;
    if (path == null) return;
    final segments =
        path.split('/').where((s) => s.isNotEmpty).toList(growable: false);
    // Expect ["pocketcoder", ns] or ["pocketcoder", ns, key].
    if (segments.isEmpty || segments.first != 'pocketcoder') return;
    if (segments.length == 2) {
      final ns = segments[1];
      switch (op['op']) {
        case 'remove':
          _pocketcoder.remove(ns);
        default:
          _pocketcoder[ns] = op['value'];
      }
      if (ns == 'permission') _syncPermission();
      if (ns == 'elicitation') _syncElicitation();
    } else if (segments.length >= 3) {
      final ns = segments[1];
      final key = segments[2];
      final existing = _pocketcoder[ns];
      final sub = existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};
      switch (op['op']) {
        case 'remove':
          sub.remove(key);
        default:
          sub[key] = op['value'];
      }
      _pocketcoder[ns] = sub;
    }
  }

  SessionState _sessionState() {
    Map<String, dynamic>? asMap(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    final sessionInfo = asMap(_pocketcoder['session_info']);
    return SessionState(
      permission: asMap(_pocketcoder['permission']),
      elicitation: asMap(_pocketcoder['elicitation']),
      modes: asMap(_pocketcoder['modes']),
      config: asMap(_pocketcoder['config']),
      plan: asMap(_pocketcoder['plan']),
      title: sessionInfo?['title'] as String?,
    );
  }

  Conversation build() {
    return Conversation(
      timeline: List.unmodifiable(_timeline),
      sessionState: _sessionState(),
    );
  }
}
```

Note: reasoning messages use `_insertTimelineItem(_timeline.length, ...)` (append) rather than a plain `_timeline.add(...)` — this keeps every mutation going through the index-tracking helper so a future change can't accidentally bypass it and desync `_toolTimelineIndex`/`_openTextIndex`. Functionally identical to `.add` when the index is `_timeline.length`.

- [x] **Step 2: Compile-check**

```bash
cd client/packages/pocketcoder_flutter
dart analyze lib/domain/agent/conversation_reducer.dart
```

Expected: no errors in this file (Task 3 will still show errors in the *test* file until it's updated next).

- [x] **Step 3: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/domain/agent/conversation_reducer.dart
git commit -m "feat(flutter): reduce AG-UI events into one ordered timeline"
```

---

### Task 3: Rewrite `conversation_reducer_test.dart` for the timeline shape

**Files:**
- Modify: `client/packages/pocketcoder_flutter/test/domain/agent/conversation_reducer_test.dart`

**Interfaces:**
- Consumes: `reduce()`, `TimelineItem` variants (Tasks 1–2).

- [x] **Step 1: Replace the `messages`/`toolCalls` assertions and add new coverage**

Replace the full body of `client/packages/pocketcoder_flutter/test/domain/agent/conversation_reducer_test.dart` (keep the file header comment, `_sync()`, `_delta()` helpers) with:

```dart
import 'package:ag_ui/ag_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/agent/conversation.dart';
import 'package:pocketcoder_flutter/domain/agent/conversation_reducer.dart';

BaseEvent _sync() =>
    CustomEvent(name: 'pocketcoder:sync', value: {'mode': 'replace'});

StateDeltaEvent _delta(String path, {String op = 'add', dynamic value}) {
  return StateDeltaEvent(delta: [
    {'op': op, 'path': path, if (value != null) 'value': value},
  ]);
}

void main() {
  group('text messages', () {
    test('START -> textStream item; CONTENT x2 -> grows in place; END -> replaced by text item',
        () {
      var conversation = reduce([
        const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
      ]);
      expect(conversation.timeline, hasLength(1));
      expect(conversation.timeline.single, isA<TextStreamTimelineItem>());
      expect((conversation.timeline.single as TextStreamTimelineItem).text, '');

      conversation = reduce([
        const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'm1', delta: 'Hello, '),
      ]);
      expect(conversation.timeline, hasLength(1));
      expect((conversation.timeline.single as TextStreamTimelineItem).text, 'Hello, ');

      conversation = reduce([
        const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'm1', delta: 'Hello, '),
        const TextMessageContentEvent(messageId: 'm1', delta: 'world!'),
        const TextMessageEndEvent(messageId: 'm1'),
      ]);
      expect(conversation.timeline, hasLength(1));
      final item = conversation.timeline.single as TextTimelineItem;
      expect(item.kind, ChatMessageKind.text);
      expect(item.role, 'assistant');
      expect(item.text, 'Hello, world!');
    });
  });

  group('reasoning messages', () {
    test('START/CONTENT/END -> one reasoning text item (no streaming placeholder)', () {
      final conversation = reduce([
        const ReasoningMessageStartEvent(messageId: 'r1'),
        const ReasoningMessageContentEvent(messageId: 'r1', delta: 'thinking...'),
        const ReasoningMessageEndEvent(messageId: 'r1'),
      ]);

      expect(conversation.timeline, hasLength(1));
      final item = conversation.timeline.single as TextTimelineItem;
      expect(item.kind, ChatMessageKind.reasoning);
      expect(item.text, 'thinking...');
    });
  });

  group('tool calls', () {
    test('START enters the timeline immediately (before ARGS/RESULT/END)', () {
      final conversation = reduce([
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
      ]);
      expect(conversation.timeline, hasLength(1));
      final item = conversation.timeline.single as ToolCallTimelineItem;
      expect(item.name, 'shell');
      expect(item.args, '');
      expect(item.result, isNull);
    });

    test('START/ARGS/RESULT/END -> one tool-call item, updated in place', () {
      final conversation = reduce([
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
        const ToolCallArgsEvent(toolCallId: 't1', delta: '{"cmd":'),
        const ToolCallArgsEvent(toolCallId: 't1', delta: '"ls"}'),
        const ToolCallResultEvent(
            messageId: 'tool-result-t1', toolCallId: 't1', content: 'file1\nfile2'),
        const ToolCallEndEvent(toolCallId: 't1'),
      ]);

      expect(conversation.timeline, hasLength(1));
      final item = conversation.timeline.single as ToolCallTimelineItem;
      expect(item.name, 'shell');
      expect(item.args, '{"cmd":"ls"}');
      expect(item.result, 'file1\nfile2');
    });
  });

  group('ordering', () {
    test('text, tool call, and more text interleave in true chronological order', () {
      final conversation = reduce([
        const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'm1', delta: 'checking...'),
        const TextMessageEndEvent(messageId: 'm1'),
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
        const ToolCallEndEvent(toolCallId: 't1'),
        const TextMessageStartEvent(messageId: 'm2', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'm2', delta: 'done'),
        const TextMessageEndEvent(messageId: 'm2'),
      ]);

      expect(conversation.timeline, hasLength(3));
      expect(conversation.timeline[0], isA<TextTimelineItem>());
      expect(conversation.timeline[1], isA<ToolCallTimelineItem>());
      expect(conversation.timeline[2], isA<TextTimelineItem>());
    });
  });

  group('permission timeline correlation', () {
    test('permission with toolCallId inserts right after that tool call', () {
      final conversation = reduce([
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
        _delta('/pocketcoder/permission',
            value: {'requestId': 'req-1', 'status': 'pending', 'toolCallId': 't1'}),
        const ToolCallStartEvent(toolCallId: 't2', toolCallName: 'other'),
      ]);

      expect(conversation.timeline, hasLength(3));
      expect((conversation.timeline[0] as ToolCallTimelineItem).id, 't1');
      expect(conversation.timeline[1], isA<PermissionTimelineItem>());
      expect((conversation.timeline[1] as PermissionTimelineItem).requestId, 'req-1');
      expect((conversation.timeline[2] as ToolCallTimelineItem).id, 't2');
    });

    test('permission with unknown/absent toolCallId appends at the end', () {
      final conversation = reduce([
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
        _delta('/pocketcoder/permission', value: {'requestId': 'req-1', 'status': 'pending'}),
      ]);

      expect(conversation.timeline, hasLength(2));
      expect(conversation.timeline.last, isA<PermissionTimelineItem>());
    });

    test('resolving a permission (STATE_DELTA remove) removes its timeline item', () {
      final conversation = reduce([
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
        _delta('/pocketcoder/permission',
            value: {'requestId': 'req-1', 'status': 'pending', 'toolCallId': 't1'}),
        _delta('/pocketcoder/permission', op: 'remove'),
      ]);

      expect(conversation.timeline, hasLength(1));
      expect(conversation.timeline.whereType<PermissionTimelineItem>(), isEmpty);
      expect(conversation.sessionState.permission, isNull);
    });

    test('a later ARGS delta on the correlated tool call still hits the right slot after insertion',
        () {
      // Regression guard for the index-shift bug: inserting the permission
      // item between t1 and where t1's ARGS update would land must not
      // corrupt _toolTimelineIndex.
      final conversation = reduce([
        const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'shell'),
        _delta('/pocketcoder/permission',
            value: {'requestId': 'req-1', 'status': 'pending', 'toolCallId': 't1'}),
        const ToolCallArgsEvent(toolCallId: 't1', delta: '{"cmd":"ls"}'),
      ]);

      final toolItem =
          conversation.timeline.whereType<ToolCallTimelineItem>().single;
      expect(toolItem.args, '{"cmd":"ls"}');
    });
  });

  group('elicitation timeline (no correlation available)', () {
    test('STATE_DELTA add /pocketcoder/elicitation -> appended at the end', () {
      final conversation = reduce([
        const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'm1', delta: 'hi'),
        const TextMessageEndEvent(messageId: 'm1'),
        _delta('/pocketcoder/elicitation', value: {
          'elicitationId': 'e1',
          'message': 'Please confirm',
          'requestedSchema': {'type': 'object'},
        }),
      ]);

      expect(conversation.timeline, hasLength(2));
      expect(conversation.timeline.last, isA<ElicitationTimelineItem>());
      expect((conversation.timeline.last as ElicitationTimelineItem).requestId, 'e1');
      expect(conversation.sessionState.elicitation?['elicitationId'], 'e1');
    });
  });

  group('permission state (sessionState back-compat)', () {
    test('STATE_DELTA add /pocketcoder/permission then remove -> present then cleared',
        () {
      final afterAdd = reduce([
        _delta('/pocketcoder/permission', value: {'status': 'pending', 'requestId': 'req-1'}),
      ]);
      expect(afterAdd.sessionState.permission, isNotNull);
      expect(afterAdd.sessionState.permission?['requestId'], 'req-1');

      final afterRemove = reduce([
        _delta('/pocketcoder/permission', value: {'status': 'pending', 'requestId': 'req-1'}),
        _delta('/pocketcoder/permission', op: 'remove'),
      ]);
      expect(afterRemove.sessionState.permission, isNull);
    });
  });

  group('elicitation state (sessionState back-compat)', () {
    test('STATE_DELTA add /pocketcoder/elicitation -> form surfaced with requestedSchema',
        () {
      final conversation = reduce([
        _delta('/pocketcoder/elicitation', value: {
          'elicitationId': 'e1',
          'message': 'Please confirm',
          'requestedSchema': {'type': 'object'},
        }),
      ]);

      final elicitation = conversation.sessionState.elicitation;
      expect(elicitation, isNotNull);
      expect(elicitation?['elicitationId'], 'e1');
      expect(elicitation?['requestedSchema'], {'type': 'object'});
    });
  });

  group('config state', () {
    test('STATE_DELTA /pocketcoder/config -> config options surfaced', () {
      final viaDelta = reduce([
        _delta('/pocketcoder/config', value: {
          'options': [
            {'kind': 'boolean', 'id': 'x', 'name': 'X', 'currentValue': true},
          ],
        }),
      ]);
      expect(viaDelta.sessionState.config?['options'], hasLength(1));
    });

    test('STATE_SNAPSHOT /pocketcoder/config -> config options surfaced', () {
      final viaSnapshot = reduce([
        StateSnapshotEvent(snapshot: {
          'pocketcoder': {
            'config': {
              'options': [
                {'kind': 'select', 'id': 'mode', 'name': 'Mode', 'currentValue': 'auto'},
              ],
            },
          },
        }),
      ]);
      expect(viaSnapshot.sessionState.config?['options'], hasLength(1));
    });
  });

  group('modes state (guards Task 3)', () {
    test('snapshot + CurrentModeUpdate-style sub-path delta -> currentModeId '
        'updated, availableModes retained', () {
      final conversation = reduce([
        StateSnapshotEvent(snapshot: {
          'pocketcoder': {
            'modes': {
              'currentModeId': 'auto',
              'availableModes': [
                {'id': 'auto', 'name': 'auto'},
                {'id': 'chat', 'name': 'chat'},
              ],
            },
          },
        }),
        _delta('/pocketcoder/modes/currentModeId', value: 'chat'),
      ]);

      final modes = conversation.sessionState.modes;
      expect(modes?['currentModeId'], 'chat');
      expect(modes?['availableModes'], hasLength(2));
    });

    test('sub-path patch applied when parent absent -> parent created, no throw',
        () {
      expect(
        () => reduce([
          _delta('/pocketcoder/modes/currentModeId', value: 'chat'),
        ]),
        returnsNormally,
      );
      final conversation = reduce([
        _delta('/pocketcoder/modes/currentModeId', value: 'chat'),
      ]);
      expect(conversation.sessionState.modes?['currentModeId'], 'chat');
    });
  });

  group('session_info state', () {
    test('STATE_DELTA session_info -> title surfaced', () {
      final conversation = reduce([
        _delta('/pocketcoder/session_info', value: {'title': 'Fix the bug'}),
      ]);
      expect(conversation.sessionState.title, 'Fix the bug');
    });
  });

  group('replace marker', () {
    test('a pocketcoder:sync CUSTOM event resets the accumulator', () {
      final conversation = reduce([
        const TextMessageStartEvent(messageId: 'stale', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'stale', delta: 'this should be discarded'),
        const TextMessageEndEvent(messageId: 'stale'),
        _delta('/pocketcoder/permission', value: {'status': 'pending'}),
        _sync(),
        const TextMessageStartEvent(messageId: 'fresh', role: TextMessageRole.assistant),
        const TextMessageContentEvent(messageId: 'fresh', delta: 'kept'),
        const TextMessageEndEvent(messageId: 'fresh'),
      ]);

      expect(conversation.timeline, hasLength(1));
      expect((conversation.timeline.single as TextTimelineItem).text, 'kept');
      expect(conversation.sessionState.permission, isNull);
    });
  });
}
```

- [x] **Step 2: Run the reducer tests**

```bash
cd client/packages/pocketcoder_flutter
flutter test test/domain/agent/conversation_reducer_test.dart
```

Expected: all tests pass. If the "regression guard" test (ARGS after insertion) fails, the bug is almost certainly a missing `_toolTimelineIndex`/`_openTextIndex` update in `_insertTimelineItem`/`_removeTimelineItemsWhere` from Task 2 — re-check those two helpers before touching the test.

- [x] **Step 3: Commit**

```bash
git add client/packages/pocketcoder_flutter/test/domain/agent/conversation_reducer_test.dart
git commit -m "test(flutter): cover the ordered timeline, streaming, and permission correlation"
```

---

### Task 4: Add `flutter_chat_ui` dependencies

**Files:**
- Modify: `client/packages/pocketcoder_flutter/pubspec.yaml`

- [x] **Step 1: Add the three new dependencies**

In `client/packages/pocketcoder_flutter/pubspec.yaml`, add to the `dependencies:` block (alongside the existing `ag_ui`/`acp_dart` lines near the bottom of that section):

```yaml
  flutter_chat_core: ^2.9.0
  flutter_chat_ui: ^2.11.1
  flyer_chat_text_stream_message: ^2.3.0
```

- [x] **Step 2: Fetch and verify**

```bash
cd client/packages/pocketcoder_flutter
flutter pub get
```

Expected: resolves cleanly. If there's a version conflict, check `flutter pub deps` for which existing dependency pins a conflicting transitive version before loosening any constraint above.

- [x] **Step 3: Commit**

```bash
git add client/packages/pocketcoder_flutter/pubspec.yaml client/packages/pocketcoder_flutter/pubspec.lock
git commit -m "chore(flutter): add flutter_chat_ui dependencies"
```

---

### Task 5: `timeline_to_messages.dart` adapter

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/chat/timeline_to_messages.dart`
- Test: `client/packages/pocketcoder_flutter/test/presentation/chat/timeline_to_messages_test.dart`

**Interfaces:**
- Consumes: `TimelineItem` (Task 1).
- Produces: `timelineToMessages(List<TimelineItem>) -> List<chat_core.Message>` and `streamStatesFromTimeline(List<TimelineItem>) -> Map<String, StreamState>` — both consumed by Task 10 (`chat_screen.dart`).
- `kUserAuthorId` / `kAgentAuthorId` constants — consumed by Task 10 (`Chat.currentUserId`) and Task 6 (bubble styling).

- [x] **Step 1: Write the failing test**

Create `client/packages/pocketcoder_flutter/test/presentation/chat/timeline_to_messages_test.dart`:

```dart
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:flutter_test/flutter_test.dart';
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart';
import 'package:pocketcoder_flutter/domain/agent/conversation.dart';
import 'package:pocketcoder_flutter/presentation/chat/timeline_to_messages.dart';

void main() {
  group('timelineToMessages', () {
    test('text item -> TextMessage with matching id/authorId/text', () {
      final out = timelineToMessages([
        const TimelineItem.text(id: 'm1', kind: ChatMessageKind.text, role: 'user', text: 'hi'),
      ]);
      expect(out, hasLength(1));
      final msg = out.single as chat_core.TextMessage;
      expect(msg.id, 'm1');
      expect(msg.authorId, kUserAuthorId);
      expect(msg.text, 'hi');
    });

    test('reasoning text item -> TextMessage tagged kind=reasoning in metadata', () {
      final out = timelineToMessages([
        const TimelineItem.text(
            id: 'r1', kind: ChatMessageKind.reasoning, role: 'assistant', text: 'thinking'),
      ]);
      final msg = out.single as chat_core.TextMessage;
      expect(msg.metadata?['kind'], 'reasoning');
      expect(msg.authorId, kAgentAuthorId);
    });

    test('textStream item -> TextStreamMessage with matching id/streamId', () {
      final out = timelineToMessages([
        const TimelineItem.textStream(id: 's1', role: 'assistant', text: 'partial'),
      ]);
      final msg = out.single as chat_core.TextStreamMessage;
      expect(msg.id, 's1');
      expect(msg.streamId, 's1');
      expect(msg.authorId, kAgentAuthorId);
    });

    test('toolCall item -> CustomMessage with kind=toolCall metadata', () {
      final out = timelineToMessages([
        const TimelineItem.toolCall(id: 't1', name: 'shell', args: '{}', result: 'ok'),
      ]);
      final msg = out.single as chat_core.CustomMessage;
      expect(msg.id, 't1');
      expect(msg.metadata?['kind'], 'toolCall');
      expect(msg.metadata?['name'], 'shell');
      expect(msg.metadata?['args'], '{}');
      expect(msg.metadata?['result'], 'ok');
    });

    test('permission item -> CustomMessage with kind=permission metadata', () {
      final out = timelineToMessages([
        const TimelineItem.permission(requestId: 'req-1'),
      ]);
      final msg = out.single as chat_core.CustomMessage;
      expect(msg.id, 'req-1');
      expect(msg.metadata?['kind'], 'permission');
    });

    test('elicitation item -> CustomMessage with kind=elicitation metadata', () {
      final out = timelineToMessages([
        const TimelineItem.elicitation(requestId: 'e1'),
      ]);
      final msg = out.single as chat_core.CustomMessage;
      expect(msg.id, 'e1');
      expect(msg.metadata?['kind'], 'elicitation');
    });

    test('preserves timeline order', () {
      final out = timelineToMessages([
        const TimelineItem.text(id: 'm1', kind: ChatMessageKind.text, role: 'user', text: 'a'),
        const TimelineItem.toolCall(id: 't1', name: 'shell'),
        const TimelineItem.text(id: 'm2', kind: ChatMessageKind.text, role: 'assistant', text: 'b'),
      ]);
      expect(out.map((m) => m.id), ['m1', 't1', 'm2']);
    });
  });

  group('streamStatesFromTimeline', () {
    test('textStream item -> StreamStateStreaming with the partial text', () {
      final out = streamStatesFromTimeline([
        const TimelineItem.textStream(id: 's1', role: 'assistant', text: 'partial'),
      ]);
      expect(out['s1'], isA<StreamStateStreaming>());
      expect((out['s1'] as StreamStateStreaming).accumulatedText, 'partial');
    });

    test('non-textStream items are not present in the map', () {
      final out = streamStatesFromTimeline([
        const TimelineItem.text(id: 'm1', kind: ChatMessageKind.text, role: 'user', text: 'a'),
      ]);
      expect(out, isEmpty);
    });
  });
}
```

- [x] **Step 2: Run to verify it fails**

```bash
cd client/packages/pocketcoder_flutter
flutter test test/presentation/chat/timeline_to_messages_test.dart
```

Expected: FAIL — `timeline_to_messages.dart` does not exist yet (import error).

- [x] **Step 3: Write the adapter**

Create `client/packages/pocketcoder_flutter/lib/presentation/chat/timeline_to_messages.dart`:

```dart
// Pure adapter: TimelineItem (domain) -> flutter_chat_core.Message (rendering).
// Called on every ChatCubit emit (see chat_screen.dart) — has no state of
// its own, just a projection of the already-reduced Conversation.timeline.
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart';
import 'package:pocketcoder_flutter/domain/agent/conversation.dart';

/// authorId used for every user-authored TimelineItem.text/.textStream
/// (matches the AG-UI `role` value the reducer already carries).
const kUserAuthorId = 'user';

/// authorId used for every agent-authored TimelineItem.text/.textStream.
const kAgentAuthorId = 'assistant';

List<chat_core.Message> timelineToMessages(List<TimelineItem> timeline) {
  return timeline.map(_toMessage).toList(growable: false);
}

chat_core.Message _toMessage(TimelineItem item) {
  return switch (item) {
    TextTimelineItem(:final id, :final kind, :final role, :final text) =>
      chat_core.Message.text(
        id: id,
        authorId: role == 'user' ? kUserAuthorId : kAgentAuthorId,
        text: text,
        metadata: {'kind': kind == ChatMessageKind.reasoning ? 'reasoning' : 'text'},
      ),
    TextStreamTimelineItem(:final id, :final role) => chat_core.Message.textStream(
        id: id,
        authorId: role == 'user' ? kUserAuthorId : kAgentAuthorId,
        streamId: id,
      ),
    ToolCallTimelineItem(:final id, :final name, :final args, :final result) =>
      chat_core.Message.custom(
        id: id,
        authorId: kAgentAuthorId,
        metadata: {'kind': 'toolCall', 'name': name, 'args': args, 'result': result},
      ),
    PermissionTimelineItem(:final requestId) => chat_core.Message.custom(
        id: requestId,
        authorId: kAgentAuthorId,
        metadata: {'kind': 'permission'},
      ),
    ElicitationTimelineItem(:final requestId) => chat_core.Message.custom(
        id: requestId,
        authorId: kAgentAuthorId,
        metadata: {'kind': 'elicitation'},
      ),
  };
}

/// Projects every currently-open streaming text item into the `StreamState`
/// map `FlyerChatTextStreamMessage` needs. Built fresh from `timeline` on
/// every rebuild — there is no separate "stream manager" to keep in sync,
/// unlike the upstream example app: this codebase's Conversation is already
/// a full up-to-date snapshot on every emit, so a pure derived map is both
/// simpler and correct (no risk of the map and the timeline disagreeing).
Map<String, StreamState> streamStatesFromTimeline(List<TimelineItem> timeline) {
  final out = <String, StreamState>{};
  for (final item in timeline) {
    if (item is TextStreamTimelineItem) {
      out[item.id] = StreamStateStreaming(item.text);
    }
  }
  return out;
}
```

- [x] **Step 4: Run to verify it passes**

```bash
flutter test test/presentation/chat/timeline_to_messages_test.dart
```

Expected: PASS, all cases green.

- [x] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/chat/timeline_to_messages.dart client/packages/pocketcoder_flutter/test/presentation/chat/timeline_to_messages_test.dart
git commit -m "feat(flutter): add TimelineItem -> flutter_chat_ui Message adapter"
```

---

### Task 6: `chat_message_bubble.dart` (text + streaming text rendering)

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/chat/chat_message_bubble.dart`

**Interfaces:**
- Produces: `ChatMessageBubble` (plain text/reasoning, for `Builders.textMessageBuilder`) and `ChatStreamMessageBubble` (in-progress, for `Builders.textStreamMessageBuilder`) — consumed by Task 10.
- Consumes: `kUserAuthorId`/`kAgentAuthorId` (Task 5) to pick the COMMANDER/POCO/THINKING label, same logic `_ChatMessageTile` uses today off `role`/`kind`.

- [x] **Step 1: Write the widget**

Create `client/packages/pocketcoder_flutter/lib/presentation/chat/chat_message_bubble.dart`. This is `chat_screen.dart`'s current `_ChatMessageTile` (lines 327–401 today), split into a completed-text variant and a streaming variant, both public:

```dart
// Renders one completed text/reasoning turn (ChatMessageBubble, wired to
// Builders.textMessageBuilder) or one in-progress streaming turn
// (ChatStreamMessageBubble, wired to Builders.textStreamMessageBuilder).
// Lifted from chat_screen.dart's old _ChatMessageTile — same terminal
// COMMANDER/POCO/THINKING styling, now driven by flutter_chat_core's
// TextMessage/TextStreamMessage + a StreamState instead of the old
// ChatMessage domain type.
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'timeline_to_messages.dart';

class ChatMessageBubble extends StatelessWidget {
  final chat_core.TextMessage message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isReasoning = message.metadata?['kind'] == 'reasoning';
    return _Bubble(
      isUser: message.authorId == kUserAuthorId,
      isReasoning: isReasoning,
      child: Text(
        message.text,
        style: TextStyle(
          color: isReasoning
              ? context.colorScheme.onSurface.withValues(alpha: 0.7)
              : context.colorScheme.onSurface,
          fontFamily: AppFonts.bodyFamily,
          package: 'pocketcoder_flutter',
          fontSize: AppSizes.fontStandard,
          fontStyle: isReasoning ? FontStyle.italic : FontStyle.normal,
          height: 1.4,
        ),
      ),
    );
  }
}

class ChatStreamMessageBubble extends StatelessWidget {
  final chat_core.TextStreamMessage message;
  final int index;
  final StreamState streamState;

  const ChatStreamMessageBubble({
    super.key,
    required this.message,
    required this.index,
    required this.streamState,
  });

  @override
  Widget build(BuildContext context) {
    return _Bubble(
      isUser: message.authorId == kUserAuthorId,
      isReasoning: false,
      child: FlyerChatTextStreamMessage(
        message: message,
        index: index,
        streamState: streamState,
        padding: EdgeInsets.zero,
        showTime: false,
        showStatus: false,
        sentTextStyle: TextStyle(
          color: context.colorScheme.onSurface,
          fontFamily: AppFonts.bodyFamily,
          package: 'pocketcoder_flutter',
          fontSize: AppSizes.fontStandard,
          height: 1.4,
        ),
        receivedTextStyle: TextStyle(
          color: context.colorScheme.onSurface,
          fontFamily: AppFonts.bodyFamily,
          package: 'pocketcoder_flutter',
          fontSize: AppSizes.fontStandard,
          height: 1.4,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final bool isUser;
  final bool isReasoning;
  final Widget child;

  const _Bubble({required this.isUser, required this.isReasoning, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    final accent = isReasoning
        ? terminalColors.warning
        : isUser
            ? terminalColors.user
            : colors.primary;
    final label = isUser ? 'COMMANDER' : (isReasoning ? 'THINKING' : 'POCO');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.space * 2,
        vertical: AppSizes.space * 1.5,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.06),
            width: AppSizes.borderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUser ? Icons.person_outline : Icons.smart_toy_outlined,
                size: 14,
                color: accent,
              ),
              HSpace.x1,
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontFamily: AppFonts.bodyFamily,
                  fontSize: AppSizes.fontTiny,
                  fontWeight: AppFonts.heavy,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          VSpace.x1,
          child,
        ],
      ),
    );
  }
}
```

- [x] **Step 2: Compile-check**

```bash
cd client/packages/pocketcoder_flutter
dart analyze lib/presentation/chat/chat_message_bubble.dart
```

Expected: no errors (this file has no test of its own — Task 10 wires it into `chat_screen.dart`, which gets end-to-end coverage via manual verification in Task 11; that matches this codebase's existing pattern of light/no dedicated tests for pure-styling leaf widgets like the old `_ChatMessageTile`).

- [x] **Step 3: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/chat/chat_message_bubble.dart
git commit -m "feat(flutter): extract ChatMessageBubble/ChatStreamMessageBubble from chat_screen"
```

---

### Task 7: `tool_call_card.dart`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/chat/tool_call_card.dart`

**Interfaces:**
- Produces: `ToolCallCard`, consumed by Task 10's `customMessageBuilder` (branch `metadata['kind'] == 'toolCall'`).

- [x] **Step 1: Write the widget**

Create `client/packages/pocketcoder_flutter/lib/presentation/chat/tool_call_card.dart` — `chat_screen.dart`'s current `_ToolCallCard` (lines 403–478 today), unchanged apart from reading its fields off `CustomMessage.metadata` instead of the old `ToolCall` domain type:

```dart
// Renders one tool invocation card. Wired to Builders.customMessageBuilder
// for metadata['kind'] == 'toolCall'. Lifted from chat_screen.dart's old
// _ToolCallCard — same terminal styling, now reading name/args/result off
// CustomMessage.metadata instead of the old ToolCall domain type.
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class ToolCallCard extends StatelessWidget {
  final chat_core.CustomMessage message;

  const ToolCallCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    final name = (message.metadata?['name'] as String?) ?? '';
    final args = (message.metadata?['args'] as String?) ?? '';
    final result = message.metadata?['result'] as String?;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSizes.space,
        vertical: AppSizes.space * 0.5,
      ),
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        color: terminalColors.attention.withValues(alpha: 0.04),
        border: Border.all(
          color: terminalColors.attention.withValues(alpha: 0.3),
          width: AppSizes.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.build_outlined,
                size: 14,
                color: terminalColors.attention,
              ),
              HSpace.x1,
              Text(
                name.toUpperCase(),
                style: TextStyle(
                  color: terminalColors.attention,
                  fontFamily: AppFonts.bodyFamily,
                  fontSize: AppSizes.fontTiny,
                  fontWeight: AppFonts.heavy,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          if (args.isNotEmpty) ...[
            VSpace.x1,
            Text(
              'ARGS: $args',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.7),
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (result != null) ...[
            VSpace.x1,
            Text(
              'RESULT: $result',
              style: TextStyle(
                color: colors.onSurface,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
```

- [x] **Step 2: Compile-check**

```bash
cd client/packages/pocketcoder_flutter
dart analyze lib/presentation/chat/tool_call_card.dart
```

- [x] **Step 3: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/chat/tool_call_card.dart
git commit -m "feat(flutter): extract ToolCallCard from chat_screen"
```

---

### Task 8: `permission_card.dart` (extract + move tests)

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/chat/permission_card.dart`
- Create: `client/packages/pocketcoder_flutter/test/presentation/chat/permission_card_test.dart`
- Modify: `client/packages/pocketcoder_flutter/test/presentation/agent/agent_widgets_test.dart` (remove the migrated `PermissionPrompt` group + its now-unused import)

**Interfaces:**
- Produces: `PermissionCard`, consumed by Task 10's `customMessageBuilder` (branch `metadata['kind'] == 'permission'`).
- Consumes: `PermissionCubit`/`PermissionState` (unchanged) via `context.read`/`BlocBuilder` — same as today's `PermissionPrompt`. The `CustomMessage` passed in is intentionally unused for data (see Task 1's `PermissionTimelineItem` doc comment: it's a position marker only) — the widget's `BlocBuilder<PermissionCubit, PermissionState>` is the only data source, exactly like today.

- [x] **Step 1: Write the widget**

Create `client/packages/pocketcoder_flutter/lib/presentation/chat/permission_card.dart` — a rename of `lib/presentation/core/widgets/permission_prompt.dart`'s `PermissionPrompt` to `PermissionCard`, unchanged internals (it already gets 100% of its data from `PermissionCubit`, not from anything passed in):

```dart
// PermissionCard: the human-in-the-loop gatekeeper surface, now rendered
// inline in the message timeline (Builders.customMessageBuilder for
// metadata['kind'] == 'permission') instead of as a standalone banner below
// the list. Renamed from presentation/core/widgets/permission_prompt.dart's
// PermissionPrompt -- internals unchanged, it already reads 100% of its
// data from PermissionCubit (the CustomMessage passed to
// customMessageBuilder is just a "render here" position marker, see
// PermissionTimelineItem in domain/agent/conversation.dart).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/agent/permission_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/permission_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';

class PermissionCard extends StatelessWidget {
  const PermissionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PermissionCubit, PermissionState>(
      builder: (context, state) {
        final permission = state.permission;
        if (permission == null) return const SizedBox.shrink();
        return _build(context, permission);
      },
    );
  }

  Widget _build(BuildContext context, Map<String, dynamic> permission) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;

    final status = (permission['status'] as String?) ?? 'pending';
    final rawOptions = permission['options'];
    final options = (rawOptions is List)
        ? rawOptions.whereType<Map>().map((o) => Map<String, dynamic>.from(o)).toList()
        : const <Map<String, dynamic>>[];

    final requestId = (permission['requestId'] as String?) ?? '';
    final toolCall = permission['toolCall'];
    final toolTitle = toolCall is Map ? toolCall['title']?.toString() : null;

    return Container(
      margin: EdgeInsets.all(AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space * 2),
      decoration: BoxDecoration(
        color: terminalColors.warning.withValues(alpha: 0.05),
        border: Border.all(
          color: terminalColors.warning.withValues(alpha: 0.3),
          width: AppSizes.borderWidth,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security_outlined,
                color: terminalColors.warning,
                size: 20,
              ),
              HSpace.x2,
              Expanded(
                child: Text(
                  context.l10n.permissionSignoffTitle,
                  style: TextStyle(
                    color: terminalColors.warning,
                    fontSize: AppSizes.fontTiny,
                    fontWeight: AppFonts.heavy,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          VSpace.x2,
          Text(
            context.l10n.permissionRequestingLabel(
              (status.isNotEmpty ? status : 'SYSTEM').toUpperCase(),
            ),
            style: TextStyle(
              color: terminalColors.warning.withValues(alpha: 0.8),
              fontSize: AppSizes.fontMini,
              fontWeight: AppFonts.heavy,
            ),
          ),
          if (toolTitle != null && toolTitle.isNotEmpty) ...[
            VSpace.x1,
            Container(
              padding: EdgeInsets.all(AppSizes.space),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.4),
                border: Border.all(
                  color: terminalColors.warning.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      toolTitle,
                      style: TextStyle(
                        color: terminalColors.warning,
                        fontFamily: AppFonts.bodyFamily,
                        fontSize: AppSizes.fontStandard,
                        fontWeight: AppFonts.heavy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (requestId.isNotEmpty) ...[
            VSpace.x1,
            Text(
              '[$requestId]',
              style: TextStyle(
                color: terminalColors.warning.withValues(alpha: 0.5),
                fontSize: AppSizes.fontMini,
              ),
            ),
          ],
          VSpace.x3,
          if (options.isEmpty)
            Row(
              children: [
                Expanded(
                  child: TerminalButton(
                    label: context.l10n.actionDeny,
                    isPrimary: false,
                    color: terminalColors.danger,
                    onTap: () => context.read<PermissionCubit>().deny(),
                  ),
                ),
                HSpace.x2,
                Expanded(
                  child: TerminalButton(
                    label: context.l10n.actionAuthorize,
                    onTap: () =>
                        context.read<PermissionCubit>().authorize(''),
                  ),
                ),
              ],
            )
          else
            for (final option in options) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ((option['name'] as String?) ?? '').toUpperCase(),
                      style: TextStyle(
                        color: terminalColors.attention,
                        fontFamily: AppFonts.bodyFamily,
                        fontSize: AppSizes.fontStandard,
                      ),
                    ),
                  ),
                  TerminalButton(
                    label: context.l10n.actionAuthorize,
                    onTap: () => context
                        .read<PermissionCubit>()
                        .authorize('${option['optionId'] ?? ''}'),
                  ),
                ],
              ),
              VSpace.x1,
            ],
          VSpace.x1,
          TerminalButton(
            label: context.l10n.actionDeny,
            isPrimary: false,
            color: terminalColors.danger,
            onTap: () => context.read<PermissionCubit>().deny(),
          ),
        ],
      ),
    );
  }
}
```

- [x] **Step 2: Move the existing `PermissionPrompt` widget tests**

Create `client/packages/pocketcoder_flutter/test/presentation/chat/permission_card_test.dart` by copying `agent_widgets_test.dart`'s `_FakeAgentChatRepository`, `_wrap`, `_settle` helpers plus the full `group('PermissionPrompt', ...)` block (lines 311–~395 today), with `PermissionPrompt` → `PermissionCard` and the import updated to `package:pocketcoder_flutter/presentation/chat/permission_card.dart`:

```dart
import 'dart:async';

import 'package:acp_dart/acp_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/agent/permission_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/agent/conversation.dart';
import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/permission_card.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class _FakeAgentChatRepository implements AgentChatRepository {
  final Map<String, StreamController<Conversation>> _controllers = {};
  final List<Map<String, Object?>> respondPermissionCalls = [];
  final List<Map<String, Object?>> respondElicitationCalls = [];

  StreamController<Conversation> controllerFor(String chatId) =>
      _controllers.putIfAbsent(chatId, () => StreamController.broadcast());

  @override
  Stream<Conversation> watch(String chatId) => controllerFor(chatId).stream;

  @override
  Future<int> cursorFor(String chatId) async => 0;

  @override
  Future<void> ingestOnce(String chatId, {required int cursor}) async {}

  @override
  Future<String> sendPrompt(String chatId, String text) async => 'run-1';

  @override
  Future<void> cancel(String chatId) async {}

  @override
  Future<void> setMode(String chatId, String modeId) async {}

  @override
  Future<void> setConfigOption(
    String chatId,
    SetSessionConfigOptionRequest req,
  ) async {}

  @override
  Future<void> respondPermission(
    String chatId,
    String requestId, {
    String? optionId,
    bool cancelled = false,
  }) async {
    respondPermissionCalls.add({
      'chatId': chatId,
      'requestId': requestId,
      'optionId': optionId,
      'cancelled': cancelled,
    });
  }

  @override
  Future<void> respondElicitation(
    String chatId,
    String elicitationId,
    ElicitationResponse resp,
  ) async {
    respondElicitationCalls.add({
      'chatId': chatId,
      'elicitationId': elicitationId,
      'resp': resp,
    });
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: child),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

void main() {
  group('PermissionCard', () {
    late _FakeAgentChatRepository repo;
    late PermissionCubit cubit;

    setUp(() {
      repo = _FakeAgentChatRepository();
      cubit = PermissionCubit(repo);
    });

    tearDown(() async {
      await cubit.close();
    });

    testWidgets(
      'renders pending permission; tapping allow calls authorize(optionId)',
      (tester) async {
        await tester.pumpWidget(_wrap(
          BlocProvider<PermissionCubit>.value(
            value: cubit,
            child: const PermissionCard(),
          ),
        ));
        await _settle(tester);

        cubit.open('chat-1');
        await _settle(tester);

        repo.controllerFor('chat-1').add(Conversation(
              sessionState: SessionState(permission: {
                'requestId': 'req-1',
                'toolCall': {'title': 'run shell'},
                'options': [
                  {
                    'optionId': 'allow-once',
                    'name': 'Allow Once',
                    'kind': 'allow_once',
                  },
                ],
              }),
            ));
        await _settle(tester);

        expect(find.text('run shell'), findsOneWidget);
        expect(find.text('ALLOW ONCE'), findsOneWidget);

        await tester.tap(find.text('AUTHORIZE').last);
        await _settle(tester);

        expect(repo.respondPermissionCalls, hasLength(1));
        expect(repo.respondPermissionCalls.single['requestId'], 'req-1');
        expect(repo.respondPermissionCalls.single['optionId'], 'allow-once');
        expect(repo.respondPermissionCalls.single['cancelled'], false);
      },
    );

    testWidgets('tapping deny calls respondPermission with cancelled:true',
        (tester) async {
      await tester.pumpWidget(_wrap(
        BlocProvider<PermissionCubit>.value(
          value: cubit,
          child: const PermissionCard(),
        ),
      ));
      await _settle(tester);

      cubit.open('chat-1');
      await _settle(tester);

      repo.controllerFor('chat-1').add(Conversation(
            sessionState: SessionState(permission: {
              'requestId': 'req-2',
              'options': [
                {'optionId': 'allow-once', 'name': 'Allow', 'kind': 'allow'},
              ],
            }),
          ));
      await _settle(tester);

      await tester.tap(find.text('DENY'));
      await _settle(tester);

      expect(repo.respondPermissionCalls, hasLength(1));
      expect(repo.respondPermissionCalls.single['requestId'], 'req-2');
      expect(repo.respondPermissionCalls.single['cancelled'], true);
    });
  });
}
```

- [x] **Step 3: Run the new test**

```bash
cd client/packages/pocketcoder_flutter
flutter test test/presentation/chat/permission_card_test.dart
```

Expected: PASS (this is the same coverage the old `PermissionPrompt` group had — should pass immediately since `PermissionCard`'s internals are unchanged from `PermissionPrompt`, just renamed).

- [x] **Step 4: Remove the migrated group from `agent_widgets_test.dart`**

Edit `client/packages/pocketcoder_flutter/test/presentation/agent/agent_widgets_test.dart`: delete the `group('PermissionPrompt', ...)` block in full, and remove the now-unused `import 'package:pocketcoder_flutter/presentation/core/widgets/permission_prompt.dart';` line. Leave `ModeSwitcher`, `ConfigPicker`, and `ElicitationForm` groups untouched for now (`ElicitationForm`'s group is handled in Task 9).

- [x] **Step 5: Run the full presentation test directory**

```bash
flutter test test/presentation/
```

Expected: PASS (the file still compiles and its remaining groups still pass — `ElicitationForm`'s import/widget still exists at this point, deleted in Task 9).

- [x] **Step 6: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/chat/permission_card.dart client/packages/pocketcoder_flutter/test/presentation/chat/permission_card_test.dart client/packages/pocketcoder_flutter/test/presentation/agent/agent_widgets_test.dart
git commit -m "feat(flutter): extract PermissionCard from PermissionPrompt for inline timeline rendering"
```

---

### Task 9: `elicitation_card.dart` (extract + move tests)

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/chat/elicitation_card.dart`
- Create: `client/packages/pocketcoder_flutter/test/presentation/chat/elicitation_card_test.dart`
- Modify: `client/packages/pocketcoder_flutter/test/presentation/agent/agent_widgets_test.dart` (remove the migrated `ElicitationForm` group + its now-unused import)

**Interfaces:**
- Produces: `ElicitationCard`, consumed by Task 10's `customMessageBuilder` (branch `metadata['kind'] == 'elicitation'`).
- Consumes: `ElicitationCubit`/`ElicitationState` (unchanged), same as today's `ElicitationForm`.
- Out of scope (see Global Constraints): no `mode == 'url'` branch — schema-form rendering only, matching today's `ElicitationForm` exactly.

- [x] **Step 1: Write the widget**

Create `client/packages/pocketcoder_flutter/lib/presentation/chat/elicitation_card.dart` — a rename of `lib/presentation/agent/elicitation_form.dart`'s `ElicitationForm` (a `StatefulWidget`) to `ElicitationCard`, internals unchanged:

```dart
// ElicitationCard: renders the pending SessionState.elicitation's
// requestedSchema as a flat form, now rendered inline in the message
// timeline (Builders.customMessageBuilder for metadata['kind'] ==
// 'elicitation') instead of as a standalone banner below the list.
// Renamed from presentation/agent/elicitation_form.dart's ElicitationForm --
// internals unchanged. Nested schema objects (oneOf, anyOf, arrays of
// objects) remain out of scope, same as before; URL-mode elicitations
// (mode == 'url') are also out of scope for this migration -- see the
// implementation plan's Global Constraints.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/agent/elicitation_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/elicitation_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';

class ElicitationCard extends StatefulWidget {
  const ElicitationCard({super.key});

  @override
  State<ElicitationCard> createState() => _ElicitationCardState();
}

class _ElicitationCardState extends State<ElicitationCard> {
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _boolValues = {};
  String? _currentElicitationId;

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _textControllerFor(String field, String? initial) {
    return _textControllers.putIfAbsent(field, () {
      return TextEditingController(text: initial ?? '');
    });
  }

  void _resetForNewElicitation(String? elicitationId) {
    if (elicitationId == _currentElicitationId) return;
    for (final c in _textControllers.values) {
      c.clear();
    }
    _boolValues.clear();
    _currentElicitationId = elicitationId;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ElicitationCubit, ElicitationState>(
      builder: (context, state) {
        final elicitation = state.elicitation;
        if (elicitation == null) return const SizedBox.shrink();

        _resetForNewElicitation(elicitation['elicitationId'] as String?);

        final message = elicitation['message'] as String?;
        final schema = elicitation['requestedSchema'];
        final properties = (schema is Map ? schema['properties'] : null)
            as Map<String, dynamic>?;

        return _buildForm(context, state, message, properties);
      },
    );
  }

  Widget _buildForm(
    BuildContext context,
    ElicitationState state,
    String? message,
    Map<String, dynamic>? properties,
  ) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;

    final elicitationId = state.elicitation?['elicitationId'];
    final fields = properties?.entries.toList() ?? const [];

    return Container(
      margin: EdgeInsets.all(AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space * 2),
      decoration: BoxDecoration(
        color: terminalColors.attention.withValues(alpha: 0.05),
        border: Border.all(
          color: terminalColors.attention.withValues(alpha: 0.3),
          width: AppSizes.borderWidth,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                color: terminalColors.attention,
                size: 20,
              ),
              HSpace.x2,
              Expanded(
                child: Text(
                  'ELICITATION REQUEST',
                  style: TextStyle(
                    color: terminalColors.attention,
                    fontSize: AppSizes.fontTiny,
                    fontWeight: AppFonts.heavy,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          if (message != null && message.isNotEmpty) ...[
            VSpace.x2,
            Text(
              message,
              style: TextStyle(
                color: terminalColors.attention,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontStandard,
              ),
            ),
          ],
          if (elicitationId != null) ...[
            VSpace.x1,
            Text(
              '[$elicitationId]',
              style: TextStyle(
                color: terminalColors.attention.withValues(alpha: 0.5),
                fontSize: AppSizes.fontMini,
              ),
            ),
          ],
          VSpace.x3,
          for (final entry in fields) ...[
            _buildField(
              context,
              name: entry.key,
              spec: entry.value is Map
                  ? Map<String, dynamic>.from(entry.value as Map)
                  : const <String, dynamic>{},
            ),
            VSpace.x2,
          ],
          if (fields.isEmpty)
            Text(
              '(no fields requested)',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.4),
                fontSize: AppSizes.fontMini,
                fontStyle: FontStyle.italic,
              ),
            ),
          VSpace.x2,
          Row(
            children: [
              Expanded(
                child: TerminalButton(
                  label: 'DECLINE',
                  isPrimary: false,
                  color: terminalColors.danger,
                  onTap: () => _submit(context, ElicitationResponse.decline()),
                ),
              ),
              HSpace.x2,
              Expanded(
                child: TerminalButton(
                  label: 'CANCEL',
                  isPrimary: false,
                  onTap: () => _submit(context, ElicitationResponse.cancel()),
                ),
              ),
              HSpace.x2,
              Expanded(
                child: TerminalButton(
                  label: 'SUBMIT',
                  onTap: () => _submit(
                    context,
                    ElicitationResponse.accept(_collectValues(properties)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    BuildContext context, {
    required String name,
    required Map<String, dynamic> spec,
  }) {
    final colors = context.colorScheme;
    final type = spec['type'] as String?;
    final title = (spec['title'] as String?) ?? name;
    final initial = spec['currentValue'];

    switch (type) {
      case 'boolean':
        final value = _boolValues.putIfAbsent(
          name,
          () => initial is bool ? initial : false,
        );
        return Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) {
                setState(() => _boolValues[name] = v ?? false);
              },
            ),
            HSpace.x1,
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: colors.onSurface,
                  fontFamily: AppFonts.bodyFamily,
                  fontSize: AppSizes.fontStandard,
                ),
              ),
            ),
          ],
        );
      case 'integer':
      case 'number':
        final controller = _textControllerFor(
          name,
          initial?.toString(),
        );
        return TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(
            labelText: title.toUpperCase(),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          style: TextStyle(
            color: colors.onSurface,
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontStandard,
          ),
        );
      case 'string':
      default:
        final controller = _textControllerFor(
          name,
          initial is String ? initial : null,
        );
        return TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: title.toUpperCase(),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          style: TextStyle(
            color: colors.onSurface,
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontStandard,
          ),
        );
    }
  }

  Map<String, dynamic> _collectValues(Map<String, dynamic>? properties) {
    final out = <String, dynamic>{};
    if (properties == null) return out;
    for (final entry in properties.entries) {
      final spec = entry.value is Map
          ? Map<String, dynamic>.from(entry.value as Map)
          : const <String, dynamic>{};
      final type = spec['type'] as String?;
      switch (type) {
        case 'boolean':
          out[entry.key] = _boolValues[entry.key] ?? false;
        case 'integer':
          final text = _textControllers[entry.key]?.text ?? '';
          out[entry.key] = int.tryParse(text) ?? 0;
        case 'number':
          final text = _textControllers[entry.key]?.text ?? '';
          out[entry.key] = double.tryParse(text) ?? 0.0;
        case 'string':
        default:
          out[entry.key] = _textControllers[entry.key]?.text ?? '';
      }
    }
    return out;
  }

  void _submit(BuildContext context, ElicitationResponse resp) {
    _currentElicitationId = null;
    for (final c in _textControllers.values) {
      c.clear();
    }
    _boolValues.clear();
    context.read<ElicitationCubit>().submit(resp);
  }
}
```

- [x] **Step 2: Move the existing `ElicitationForm` widget tests**

Create `client/packages/pocketcoder_flutter/test/presentation/chat/elicitation_card_test.dart` following the exact same pattern as Task 8 Step 2 (copy the fake repo/`_wrap`/`_settle` helpers, then the `group('ElicitationForm', ...)` block from `agent_widgets_test.dart`, lines 235–309 today), with `ElicitationForm` → `ElicitationCard`, importing `package:pocketcoder_flutter/presentation/chat/elicitation_card.dart`, and `ElicitationCubit` swapped in for `PermissionCubit` throughout (mirror Task 8's fake-repo trimming — this file only needs `respondElicitationCalls`/`respondElicitation`, not the permission fields):

```dart
import 'dart:async';

import 'package:acp_dart/acp_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/agent/elicitation_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/agent/conversation.dart';
import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/elicitation_card.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class _FakeAgentChatRepository implements AgentChatRepository {
  final Map<String, StreamController<Conversation>> _controllers = {};
  final List<Map<String, Object?>> respondElicitationCalls = [];

  StreamController<Conversation> controllerFor(String chatId) =>
      _controllers.putIfAbsent(chatId, () => StreamController.broadcast());

  @override
  Stream<Conversation> watch(String chatId) => controllerFor(chatId).stream;

  @override
  Future<int> cursorFor(String chatId) async => 0;

  @override
  Future<void> ingestOnce(String chatId, {required int cursor}) async {}

  @override
  Future<String> sendPrompt(String chatId, String text) async => 'run-1';

  @override
  Future<void> cancel(String chatId) async {}

  @override
  Future<void> setMode(String chatId, String modeId) async {}

  @override
  Future<void> setConfigOption(
    String chatId,
    SetSessionConfigOptionRequest req,
  ) async {}

  @override
  Future<void> respondPermission(
    String chatId,
    String requestId, {
    String? optionId,
    bool cancelled = false,
  }) async {}

  @override
  Future<void> respondElicitation(
    String chatId,
    String elicitationId,
    ElicitationResponse resp,
  ) async {
    respondElicitationCalls.add({
      'chatId': chatId,
      'elicitationId': elicitationId,
      'resp': resp,
    });
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: child),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

void main() {
  group('ElicitationCard', () {
    late _FakeAgentChatRepository repo;
    late ElicitationCubit cubit;

    setUp(() {
      repo = _FakeAgentChatRepository();
      cubit = ElicitationCubit(repo);
    });

    tearDown(() async {
      await cubit.close();
    });

    testWidgets(
      'renders the form for a pending elicitation; submit calls respondElicitation',
      (tester) async {
        await tester.pumpWidget(_wrap(
          BlocProvider<ElicitationCubit>.value(
            value: cubit,
            child: const ElicitationCard(),
          ),
        ));
        await _settle(tester);

        cubit.open('chat-1');
        await _settle(tester);

        repo.controllerFor('chat-1').add(Conversation(
              sessionState: SessionState(elicitation: {
                'elicitationId': 'elic-1',
                'message': 'Pick a value',
                'requestedSchema': {
                  'type': 'object',
                  'properties': {
                    'color': {'type': 'string', 'title': 'Color'},
                  },
                },
              }),
            ));
        await _settle(tester);

        expect(find.text('Pick a value'), findsOneWidget);
        expect(find.text('SUBMIT'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'blue');
        await tester.tap(find.text('SUBMIT'));
        await _settle(tester);

        expect(repo.respondElicitationCalls, hasLength(1));
        expect(repo.respondElicitationCalls.single['elicitationId'], 'elic-1');
        final resp = repo.respondElicitationCalls.single['resp']
            as ElicitationResponse;
        expect(resp.toJson(), {
          'action': 'accept',
          'content': {'color': 'blue'},
        });
      },
    );

    testWidgets('renders nothing when no elicitation is pending',
        (tester) async {
      await tester.pumpWidget(_wrap(
        BlocProvider<ElicitationCubit>.value(
          value: cubit,
          child: const ElicitationCard(),
        ),
      ));
      await _settle(tester);

      cubit.open('chat-1');
      await _settle(tester);

      expect(find.text('SUBMIT'), findsNothing);
    });
  });
}
```

- [x] **Step 3: Run the new test**

```bash
cd client/packages/pocketcoder_flutter
flutter test test/presentation/chat/elicitation_card_test.dart
```

Expected: PASS.

- [x] **Step 4: Remove the migrated group from `agent_widgets_test.dart`**

Edit `client/packages/pocketcoder_flutter/test/presentation/agent/agent_widgets_test.dart`: delete the `group('ElicitationForm', ...)` block and the now-unused `import 'package:pocketcoder_flutter/presentation/agent/elicitation_form.dart';` line. `ModeSwitcher`/`ConfigPicker` groups (and the shared `_FakeAgentChatRepository`/`_wrap`/`_settle` helpers, still used by those) stay.

- [x] **Step 5: Run the full test suite**

```bash
flutter test
```

Expected: PASS. This is the first point where the *entire* test suite (not just the chat-related files) should be green again since Task 1 — everything up to `chat_screen.dart` itself is now migrated; `chat_screen.dart` is fixed next.

- [x] **Step 6: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/chat/elicitation_card.dart client/packages/pocketcoder_flutter/test/presentation/chat/elicitation_card_test.dart client/packages/pocketcoder_flutter/test/presentation/agent/agent_widgets_test.dart
git commit -m "feat(flutter): extract ElicitationCard from ElicitationForm for inline timeline rendering"
```

---

### Task 10: Rewrite `chat_screen.dart` to use `flutter_chat_ui`

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/presentation/chat/chat_screen.dart`

**Interfaces:**
- Consumes: `timelineToMessages`/`streamStatesFromTimeline`/`kUserAuthorId`/`kAgentAuthorId` (Task 5), `ChatMessageBubble`/`ChatStreamMessageBubble` (Task 6), `ToolCallCard` (Task 7), `PermissionCard` (Task 8), `ElicitationCard` (Task 9).
- `ChatCubit`/`PermissionCubit`/`ElicitationCubit`/`SessionControlsCubit` providers, `_opened`/`didUpdateWidget` lifecycle, `PlanPanel`/`ModeSwitcher`/`ConfigPicker`/`_SimpleInput` — all unchanged from today.

- [x] **Step 1: Rewrite the file**

Replace `client/packages/pocketcoder_flutter/lib/presentation/chat/chat_screen.dart` in full:

```dart
// ChatScreen: renders the reduced Conversation (ordered timeline + session
// state surfaces) from ChatCubit via BlocBuilder<ChatCubit, ChatState>,
// using flutter_chat_ui's Chat widget for the message list instead of a
// hand-rolled ListView. Sub-surfaces (mode, config, plan) stay as separate
// widgets around it -- they're session-wide chrome, not per-message.
// Permission/elicitation moved INTO the timeline (see
// docs/superpowers/specs/2026-07-21-flutter-chat-ui-migration-design.md):
// PermissionCard/ElicitationCard render via customMessageBuilder now,
// instead of as standalone banners below the list.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as chat_ui;
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart'
    as chat_stream;
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/agent/chat_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/chat_state.dart';
import 'package:pocketcoder_flutter/application/agent/elicitation_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/permission_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/agent/config_picker.dart';
import 'package:pocketcoder_flutter/presentation/agent/mode_switcher.dart';
import 'package:pocketcoder_flutter/presentation/agent/plan_panel.dart';
import 'package:pocketcoder_flutter/presentation/chat/chat_message_bubble.dart';
import 'package:pocketcoder_flutter/presentation/chat/elicitation_card.dart';
import 'package:pocketcoder_flutter/presentation/chat/permission_card.dart';
import 'package:pocketcoder_flutter/presentation/chat/timeline_to_messages.dart';
import 'package:pocketcoder_flutter/presentation/chat/tool_call_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';

class ChatScreen extends StatelessWidget {
  final String? chatId;

  const ChatScreen({super.key, this.chatId});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ChatCubit>(create: (_) => getIt<ChatCubit>()),
        BlocProvider<PermissionCubit>(create: (_) => getIt<PermissionCubit>()),
        BlocProvider<ElicitationCubit>(create: (_) => getIt<ElicitationCubit>()),
        BlocProvider<SessionControlsCubit>(
            create: (_) => getIt<SessionControlsCubit>()),
      ],
      child: _ChatView(chatId: chatId),
    );
  }
}

class _ChatView extends StatefulWidget {
  final String? chatId;

  const _ChatView({this.chatId});

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final TextEditingController _inputController = TextEditingController();
  final chat_core.InMemoryChatController _chatController =
      chat_core.InMemoryChatController();
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _opened) return;
      _opened = true;
      final id = widget.chatId;
      if (id == null || id.isEmpty || id == 'new') return;
      final chatCubit = context.read<ChatCubit>();
      chatCubit.open(id);
      context.read<PermissionCubit>().open(id);
      context.read<ElicitationCubit>().open(id);
      context.read<SessionControlsCubit>().open(id);
    });
  }

  @override
  void didUpdateWidget(covariant _ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chatId != oldWidget.chatId &&
        widget.chatId != null &&
        widget.chatId!.isNotEmpty &&
        widget.chatId != 'new') {
      _opened = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _opened = true;
        final id = widget.chatId!;
        context.read<ChatCubit>().open(id);
        context.read<PermissionCubit>().open(id);
        context.read<ElicitationCubit>().open(id);
        context.read<SessionControlsCubit>().open(id);
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _handleSubmit(BuildContext context) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final chatCubit = context.read<ChatCubit>();
    if (chatCubit.state.chatId == null) return;
    chatCubit.sendPrompt(text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, commState) {
        final title = commState.conversation.sessionState.title ??
            context.l10n.chatSessionTitle;
        final isRunning = commState.status == UiFlowStatus.loading ||
            commState.lastOperation == AgentChatOperation.sendPrompt;

        _chatController.setMessages(
            timelineToMessages(commState.conversation.timeline));
        final streamStates =
            streamStatesFromTimeline(commState.conversation.timeline);

        return PocketCoderShell(
          title: title,
          activePillar: NavPillar.chats,
          showBack: true,
          extraHeaderActions: [
            if (isRunning)
              TerminalAction(
                label: 'CANCEL',
                onTap: () => context.read<ChatCubit>().cancel(),
              ),
            TerminalAction(
              label: context.l10n.chatTerminalAction,
              onTap: () => AppNavigation.toTerminal(context),
            ),
            TerminalAction(
              label: context.l10n.chatFilesAction,
              onTap: () => AppNavigation.toFiles(context),
            ),
          ],
          padding: EdgeInsets.zero,
          body: MultiBlocListener(
            listeners: [
              BlocListener<ChatCubit, ChatState>(
                listenWhen: (previous, current) =>
                    previous.error != current.error && current.error != null,
                listener: (context, state) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${state.error}')),
                  );
                },
              ),
            ],
            child: Column(
              children: [
                const PlanPanel(),
                Expanded(
                  child: commState.conversation.timeline.isEmpty
                      ? Center(
                          child: Text(
                            context.l10n.chatSessionTitle,
                            style: TextStyle(
                              color: context.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                              fontSize: AppSizes.fontStandard,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : chat_ui.Chat(
                          currentUserId: kUserAuthorId,
                          resolveUser: (id) async => chat_core.User(id: id),
                          chatController: _chatController,
                          builders: chat_ui.Builders(
                            textMessageBuilder: (context, message, index,
                                    {required isSentByMe, groupStatus}) =>
                                ChatMessageBubble(message: message),
                            textStreamMessageBuilder: (context, message, index,
                                    {required isSentByMe, groupStatus}) =>
                                ChatStreamMessageBubble(
                              message: message,
                              index: index,
                              streamState: streamStates[message.id] ??
                                  const chat_stream.StreamStateLoading(),
                            ),
                            customMessageBuilder: (context, message, index,
                                {required isSentByMe, groupStatus}) {
                              switch (message.metadata?['kind']) {
                                case 'toolCall':
                                  return ToolCallCard(message: message);
                                case 'permission':
                                  return const PermissionCard();
                                case 'elicitation':
                                  return const ElicitationCard();
                                default:
                                  return const SizedBox.shrink();
                              }
                            },
                            composerBuilder: (context) => Padding(
                              padding: EdgeInsets.all(AppSizes.space),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (commState.isLoading) ...[
                                    TerminalLoadingIndicator(
                                      label: context.l10n.chatThinking,
                                    ),
                                    VSpace.x1,
                                  ],
                                  _SimpleInput(
                                    controller: _inputController,
                                    enabled: !commState.isLoading &&
                                        commState.chatId != null,
                                    onSubmitted: () => _handleSubmit(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SimpleInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmitted;

  const _SimpleInput({
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.space * 2,
        vertical: AppSizes.space * 1.5,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.2),
            width: AppSizes.borderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            '\$ ',
            style: TextStyle(
              color: enabled
                  ? terminalColors.attention
                  : colors.onSurface.withValues(alpha: 0.3),
              fontFamily: AppFonts.bodyFamily,
              package: 'pocketcoder_flutter',
              fontSize: AppSizes.fontStandard,
              fontWeight: AppFonts.heavy,
            ),
          ),
          Expanded(
            child: TextField(
              enabled: enabled,
              controller: controller,
              onSubmitted: (_) => onSubmitted(),
              style: TextStyle(
                color: terminalColors.attention,
                fontFamily: AppFonts.bodyFamily,
                package: 'pocketcoder_flutter',
                fontSize: AppSizes.fontStandard,
              ),
              cursorColor: terminalColors.attention,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Notes on this rewrite:
- `_chatController` is a `State` field (not rebuilt per `build()`) so `Chat` keeps the same controller instance across rebuilds — only `setMessages(...)` changes, which is what drives the diff/animation. It's disposed in `dispose()`.
- The empty-state branch (`commState.conversation.timeline.isEmpty`) is kept as a plain `Center(Text(...))` rather than handed to `Chat`, matching today's behavior exactly (today's `_ConversationList` also short-circuits before building a `ListView` when both lists are empty) and sidestepping any question of how `Chat`/`InMemoryChatController` render a zero-message list.
- `composerBuilder` returns the exact same `Padding`+loading-indicator+`_SimpleInput` structure `chat_screen.dart` builds today — the input bar's behavior/styling is unchanged, only its position in the widget tree moves (from a sibling of the list to a builder `Chat` calls internally).
- `resolveUser` returns a minimal `chat_core.User(id: id)` — none of the custom builders above use the resolved `User` object (they all read data off `message`/the Cubits directly), so this only needs to satisfy the required parameter, not carry real profile data.

- [x] **Step 2: Regenerate + analyze**

```bash
cd client/packages/pocketcoder_flutter
dart run build_runner build --delete-conflicting-outputs
dart analyze lib/presentation/chat/chat_screen.dart
```

Expected: no errors. If `Builders`/`Chat`/`InMemoryChatController` are reported unresolved, re-check Task 4's `pubspec.yaml` edit landed and `flutter pub get` was re-run.

- [x] **Step 3: Full analyze + test pass**

```bash
dart analyze
flutter test
```

Expected: zero analyzer errors, all tests pass.

- [x] **Step 4: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/chat/chat_screen.dart
git commit -m "feat(flutter): render the chat timeline with flutter_chat_ui"
```

---

### Task 11: Delete superseded widgets, final verification

**Files:**
- Delete: `client/packages/pocketcoder_flutter/lib/presentation/core/widgets/permission_prompt.dart`
- Delete: `client/packages/pocketcoder_flutter/lib/presentation/agent/elicitation_form.dart`

- [x] **Step 1: Confirm nothing else references the old widgets**

```bash
cd client/packages/pocketcoder_flutter
grep -rn "PermissionPrompt\b" lib test
grep -rn "\bElicitationForm\b" lib test
```

Expected: no output (Tasks 8–9 already removed every reference — this is a safety check before deleting).

- [x] **Step 2: Delete the files**

```bash
git rm client/packages/pocketcoder_flutter/lib/presentation/core/widgets/permission_prompt.dart
git rm client/packages/pocketcoder_flutter/lib/presentation/agent/elicitation_form.dart
```

- [x] **Step 3: Full verification**

```bash
cd client/packages/pocketcoder_flutter
dart analyze
flutter test
```

Expected: zero analyzer errors/warnings introduced by this migration, all tests pass.

- [x] **Step 4: Commit**

```bash
git commit -m "chore(flutter): remove PermissionPrompt/ElicitationForm, superseded by PermissionCard/ElicitationCard"
```

- [ ] **Step 5: Manual verification (required before calling this done — UI change) — DEFERRED, not yet performed. Analyzer + full test suite are green; this browser walkthrough still needs to happen before fully trusting the new timeline UI.**

Per this project's standing rule for frontend changes: start the dev server / run the app and actually exercise the feature before reporting success; analyzer + unit tests verify correctness, not the feel of the UI.

```bash
./client/scripts/run_chrome_incognito.sh
```

Walk through, against a real or locally-run backend:
1. Open an existing chat with prior history — confirm messages/tool calls render in the same chronological order they occurred (this is the ordering bug fix from Task 2 — worth specifically comparing against `git stash`'d pre-migration behavior if in doubt).
2. Send a prompt that triggers at least one tool call — confirm the reply text visibly streams in (not just pops in complete) and the tool call card appears inline at the right point in the timeline.
3. Trigger a permission-gated tool call (or use a test chat/mock that does) — confirm the permission card renders inline immediately after its tool call, not as a banner below the list, and that AUTHORIZE/DENY still work end to end.
4. Trigger an elicitation — confirm the form renders inline and SUBMIT/DECLINE/CANCEL still work end to end.
5. Confirm `PlanPanel`/`ModeSwitcher`/`ConfigPicker` (session-wide chrome, untouched by this migration) still render/function as before.

If any of these don't hold, do not mark this plan complete — file what's broken and fix it before moving on.
