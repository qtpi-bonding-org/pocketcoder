import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/models/message.dart';

void main() {
  group('Message Verbatim Alignment', () {
    test('Message.fromJson handles minimal PocketBase json', () {
      final json = {
        'id': 'msg-1',
        'chat': 'chat-1',
        'role': 'assistant',
        'parts': [
          {'type': 'text', 'text': 'Hello World'}
        ],
        'created': '2026-02-10T04:46:28.000Z',
      };

      final message = Message.fromJson(json);

      expect(message.id, 'msg-1');
      expect(message.chat, 'chat-1');
      expect(message.role, MessageRole.assistant);
      expect(message.parts, isA<List>());
      expect(message.parts.length, 1);
      expect(message.parts.first['type'], 'text');
      expect(message.parts.first['text'], 'Hello World');
      expect(message.created, isA<DateTime>());
      expect(message.created?.year, 2026);
    });

    test('Message.fromJson handles missing parts as null (per verbatim)', () {
      final json = {
        'id': 'msg-2',
        'chat': 'chat-1',
        'role': 'user',
        // 'parts' is missing
      };

      final message = Message.fromJson(json);

      expect(message.parts, isNull);
    });

    test(
        'Message.fromJson handles empty string status as unknown (PB behavior)',
        () {
      final json = {
        'id': 'msg-empty-status',
        'chat': 'chat-1',
        'role': 'assistant',
        'engine_message_status': '',
      };

      final message = Message.fromJson(json);
      // Since it's a non-required enum, if the value is not in the set, it usually defaults to unknown or null depending on json_serializable
      expect(message.engineMessageStatus, MessageEngineMessageStatus.unknown);
    });

    test('Message.fromJson handles tool parts', () {
      final json = {
        'id': 'msg-tool',
        'chat': 'chat-1',
        'role': 'assistant',
        'parts': [
          {
            'type': 'tool',
            'tool': 'bash',
            'callID': 'call-123',
            'state': {
              'status': 'completed',
              'input': {'command': 'ls'},
              'output': 'file1.txt\nfile2.txt',
            }
          }
        ]
      };

      final message = Message.fromJson(json);

      expect(message.parts.first['type'], 'tool');
      final toolPart = message.parts.first as Map<String, dynamic>;
      expect(toolPart['tool'], 'bash');
      expect(toolPart['state']['status'], 'completed');
      expect(toolPart['state']['input']['command'], 'ls');
    });

    test('Message.fromJson handles reasoning parts', () {
      final json = {
        'id': 'msg-reasoning',
        'chat': 'chat-1',
        'role': 'assistant',
        'parts': [
          {
            'type': 'reasoning',
            'text': 'I am thinking about...',
          }
        ]
      };

      final message = Message.fromJson(json);

      expect(message.parts.first['type'], 'reasoning');
      expect(message.parts.first['text'], 'I am thinking about...');
    });
  });
}
