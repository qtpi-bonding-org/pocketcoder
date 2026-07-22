// Pure fold: List<AguiEvent> -> Conversation. No I/O — this is the single
// place that understands AG-UI event semantics (message/reasoning/tool
// lifecycles, /pocketcoder/* state deltas, the cold-replay replace marker)
// so everything downstream (cubits, widgets) only ever sees [Conversation].
import 'package:pocketcoder_flutter/domain/agent/conversation.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agui_decode.dart';
import 'package:ag_ui/ag_ui.dart' as ag_ui;

/// Reduces an ordered list of AG-UI events into a [Conversation]. A
/// `pocketcoder:sync` replace-marker CUSTOM event (see `isReplaceMarker`,
/// Task 7) resets the accumulator — events before it in the list are
/// discarded, matching the cold-replay "Goose wins" semantics (spec §5.2):
/// the client rebuilds from the marker forward rather than appending.
Conversation reduce(List<ag_ui.BaseEvent> events) {
  final builder = _ConversationBuilder();
  for (final event in events) {
    if (isReplaceMarker(event)) {
      builder.reset();
      continue;
    }
    builder.apply(event);
  }
  return builder.build();
}

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
