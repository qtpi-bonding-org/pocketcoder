import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/domain/chat/chat_message.dart';

void main() {
  group('ChatMessage & MessagePart Alignment', () {
    test('ChatMessage.fromJson handles minimal PocketBase json', () {
      final json = {
        'id': 'msg-1',
        'chat': 'chat-1',
        'role': 'assistant',
        'parts': [
          {'type': 'text', 'text': 'Hello World'}
        ],
        'created': '2026-02-10T04:46:28.000Z',
      };

      final message = ChatMessage.fromJson(json);

      expect(message.id, 'msg-1');
      expect(message.chat, 'chat-1');
      expect(message.role, MessageRole.assistant);
      expect(message.parts?.length, 1);
      expect(message.parts?.first, isA<MessagePartText>());
      expect((message.parts?.first as MessagePartText?)?.text, 'Hello World');
      expect(message.created, isA<DateTime>());
      expect(message.created?.year, 2026);
    });

    test(
        'ChatMessage.fromJson handles missing parts by defaulting to empty list',
        () {
      final json = {
        'id': 'msg-2',
        'chat': 'chat-1',
        'role': 'user',
        // 'parts' is missing
      };

      final message = ChatMessage.fromJson(json);

      expect(message.parts, isNull);
    });

    test('ChatMessage.fromJson handles empty string status as null', () {
      final json = {
        'id': 'msg-empty-status',
        'chat': 'chat-1',
        'role': 'assistant',
        'status': '',
      };

      final message = ChatMessage.fromJson(json);
      expect(message.engineMessageStatus, isNull);
    });

    test('MessagePart.fromJson handles tool parts with nested ToolState', () {
      final json = {
        'type': 'tool',
        'tool': 'bash',
        'callID': 'call-123',
        'state': {
          'status': 'completed',
          'input': {'command': 'ls'},
          'output': 'file1.txt\nfile2.txt',
        }
      };

      final part = MessagePart.fromJson(json);

      expect(part, isA<MessagePartTool>());
      final toolPart = part as MessagePartTool;
      expect(toolPart.tool, 'bash');
      expect(toolPart.state, isA<ToolStateCompleted>());
      final state = toolPart.state as ToolStateCompleted;
      expect(state.input['command'], 'ls');
      expect(state.output, contains('file1.txt'));
    });

    test('MessagePartText handles "content" key as fallback for "text"', () {
      final json = {
        'type': 'text',
        'content': 'Fallback content', // Old schema or OpenCode variety
      };

      final part = MessagePart.fromJson(json);

      expect(part, isA<MessagePartText>());
      expect((part as MessagePartText).text, 'Fallback content');
    });

    test('MessagePart.fromJson handles reasoning parts', () {
      final json = {
        'type': 'reasoning',
        'text': 'I am thinking about...',
      };

      final part = MessagePart.fromJson(json);

      expect(part, isA<MessagePartReasoning>());
      expect((part as MessagePartReasoning).text, 'I am thinking about...');
    });
  });
}
