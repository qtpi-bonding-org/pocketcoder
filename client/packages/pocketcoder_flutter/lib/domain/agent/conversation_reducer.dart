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

class _OpenTool {
  _OpenTool(this.name);
  String name;
  final StringBuffer args = StringBuffer();
  String? result;
}

class _ConversationBuilder {
  final List<ChatMessage> _messages = [];
  final List<ToolCall> _toolCalls = [];
  final Map<String, _OpenMessage> _openText = {};
  final Map<String, _OpenMessage> _openReasoning = {};
  final Map<String, _OpenTool> _openTools = {};
  final Map<String, dynamic> _pocketcoder = {};

  void reset() {
    _messages.clear();
    _toolCalls.clear();
    _openText.clear();
    _openReasoning.clear();
    _openTools.clear();
    _pocketcoder.clear();
  }

  void apply(ag_ui.BaseEvent event) {
    switch (event) {
      case ag_ui.TextMessageStartEvent():
        _openText[event.messageId] = _OpenMessage(event.role.value);
      case ag_ui.TextMessageContentEvent():
        _openText
            .putIfAbsent(event.messageId, () => _OpenMessage('assistant'))
            .text
            .write(event.delta);
      case ag_ui.TextMessageEndEvent():
        final open = _openText.remove(event.messageId);
        if (open != null) {
          _messages.add(ChatMessage(
            id: event.messageId,
            kind: ChatMessageKind.text,
            role: open.role,
            text: open.text.toString(),
          ));
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
          _messages.add(ChatMessage(
            id: event.messageId,
            kind: ChatMessageKind.reasoning,
            role: open.role,
            text: open.text.toString(),
          ));
        }

      case ag_ui.ToolCallStartEvent():
        _openTools[event.toolCallId] = _OpenTool(event.toolCallName);
      case ag_ui.ToolCallArgsEvent():
        _openTools
            .putIfAbsent(event.toolCallId, () => _OpenTool(''))
            .args
            .write(event.delta);
      case ag_ui.ToolCallResultEvent():
        _openTools
            .putIfAbsent(event.toolCallId, () => _OpenTool(''))
            .result = event.content;
      case ag_ui.ToolCallEndEvent():
        final open = _openTools.remove(event.toolCallId);
        if (open != null) {
          _toolCalls.add(ToolCall(
            id: event.toolCallId,
            name: open.name,
            args: open.args.toString(),
            result: open.result,
          ));
        }

      case ag_ui.StateSnapshotEvent():
        final snapshot = event.snapshot;
        if (snapshot is Map) {
          final pocketcoder = snapshot['pocketcoder'];
          _pocketcoder
            ..clear()
            ..addAll(pocketcoder is Map ? Map<String, dynamic>.from(pocketcoder) : {});
        }
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
      messages: List.unmodifiable(_messages),
      toolCalls: List.unmodifiable(_toolCalls),
      sessionState: _sessionState(),
    );
  }
}
