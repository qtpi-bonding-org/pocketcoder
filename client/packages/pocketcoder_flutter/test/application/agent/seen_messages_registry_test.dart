import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/agent/seen_messages_registry.dart';

void main() {
  group('SeenMessagesRegistry', () {
    test('a message is unseen until marked seen', () {
      final registry = SeenMessagesRegistry();
      expect(registry.hasSeen('chat-1', 'm1'), isFalse);
    });

    test('marking seen persists for that chat/message pair', () {
      final registry = SeenMessagesRegistry();
      registry.markSeen('chat-1', 'm1');
      expect(registry.hasSeen('chat-1', 'm1'), isTrue);
    });

    test('seen state is scoped per chat id', () {
      final registry = SeenMessagesRegistry();
      registry.markSeen('chat-1', 'm1');
      expect(registry.hasSeen('chat-2', 'm1'), isFalse);
    });

    test('seenIdsFor returns every id marked seen for that chat', () {
      final registry = SeenMessagesRegistry();
      registry.markSeen('chat-1', 'm1');
      registry.markSeen('chat-1', 'm2');
      expect(registry.seenIdsFor('chat-1'), {'m1', 'm2'});
      expect(registry.seenIdsFor('chat-2'), isEmpty);
    });
  });
}
