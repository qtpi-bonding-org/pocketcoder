// Domain output of ConversationReducer (plan Task 10): the reduced view of
// an AG-UI event stream that the presentation layer renders. Pure data —
// no AG-UI/ACP types leak in here, so widgets never need to know the wire
// protocol.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation.freezed.dart';

enum ChatMessageKind { text, reasoning }

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
