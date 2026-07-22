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
