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
