// Domain output of ConversationReducer (plan Task 10): the reduced view of
// an AG-UI event stream that the presentation layer renders. Pure data —
// no AG-UI/ACP types leak in here, so widgets never need to know the wire
// protocol.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation.freezed.dart';

enum ChatMessageKind { text, reasoning }

/// One rendered message: either assistant/user prose (`text`) or an
/// assistant reasoning block (`reasoning`). Built by concatenating every
/// `*_CONTENT` delta between a message's `*_START` and `*_END`.
@freezed
sealed class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required ChatMessageKind kind,
    required String role,
    required String text,
  }) = _ChatMessage;
}

/// One tool invocation: `args` accumulates TOOL_CALL_ARGS deltas (raw JSON
/// text, not parsed — the widget layer decides how to render it), `result`
/// is set once a TOOL_CALL_RESULT arrives (a tool call may end with no
/// result, e.g. if cancelled).
@freezed
sealed class ToolCall with _$ToolCall {
  const factory ToolCall({
    required String id,
    required String name,
    @Default('') String args,
    String? result,
  }) = _ToolCall;
}

/// The surfaced `/pocketcoder/*` ambient state namespaces (spec §5.4).
/// `commands` and `usage` are parsed-past but intentionally not surfaced in
/// v1 (documented in the design spec §9) — the reducer drops them.
@freezed
sealed class SessionState with _$SessionState {
  const factory SessionState({
    Map<String, dynamic>? permission,
    Map<String, dynamic>? elicitation,
    Map<String, dynamic>? modes,
    Map<String, dynamic>? config,
    Map<String, dynamic>? plan,
    String? title,
  }) = _SessionState;

  const SessionState._();

  static const empty = SessionState();
}

/// The full reduced view of a chat's AG-UI event stream: the message/tool
/// timeline plus the ambient session state. `reduce()` (in
/// conversation_reducer.dart) is the only producer.
@freezed
sealed class Conversation with _$Conversation {
  const factory Conversation({
    @Default(<ChatMessage>[]) List<ChatMessage> messages,
    @Default(<ToolCall>[]) List<ToolCall> toolCalls,
    @Default(SessionState.empty) SessionState sessionState,
  }) = _Conversation;

  const Conversation._();

  static const empty = Conversation();
}
