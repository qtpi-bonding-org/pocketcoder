import 'package:ag_ui/ag_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/pocketcoder_ag_ui_transport.dart';

import '../../fakes/fake_agent_chat_repository.dart';

void main() {
  test('events stream emits only new raw events since the last cache emission', () async {
    final fakeRepo = FakeAgentChatRepository();
    final transport = PocketcoderAgUiTransport(fakeRepo, chatId: 'c1');

    final received = <BaseEvent>[];
    final sub = transport.events.listen(received.add);

    fakeRepo.emitRawEvents([
      const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(1));

    fakeRepo.emitRawEvents([
      const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
      const TextMessageContentEvent(messageId: 'm1', delta: 'hi'),
    ]);
    await Future<void>.delayed(Duration.zero);
    // Only the NEW event (content) should have been emitted, not a repeat
    // of the START already seen.
    expect(received, hasLength(2));
    expect(received.last, isA<TextMessageContentEvent>());

    await sub.cancel();
    await transport.dispose();
  });

  test('a cache shrink (cold-replay reset) synthesizes a reset marker before replaying', () async {
    final fakeRepo = FakeAgentChatRepository();
    final transport = PocketcoderAgUiTransport(fakeRepo, chatId: 'c1');

    final received = <BaseEvent>[];
    final sub = transport.events.listen(received.add);

    fakeRepo.emitRawEvents([
      const TextMessageStartEvent(messageId: 'stale', role: TextMessageRole.assistant),
      const TextMessageEndEvent(messageId: 'stale'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(2));

    // Simulate AgentChatRepository.ingestOnce's cold-replay clearChat: the
    // cache shrinks to a single fresh row, with NO marker event in it
    // (ingestOnce consumes the marker before it ever reaches the cache —
    // see Step 8's implementation comment for why).
    fakeRepo.emitRawEvents([
      const TextMessageStartEvent(messageId: 'fresh', role: TextMessageRole.assistant),
    ]);
    await Future<void>.delayed(Duration.zero);

    // transport must have synthesized a reset marker itself before
    // replaying, so a downstream ConversationReducer actually resets
    // instead of accumulating stale + fresh state.
    expect(received[2], isA<CustomEvent>());
    expect((received[2] as CustomEvent).name, 'pocketcoder:sync');
    expect(received[3], isA<TextMessageStartEvent>());
    expect((received[3] as TextMessageStartEvent).messageId, 'fresh');

    await sub.cancel();
    await transport.dispose();
  });

  test(
      'a same-length replay that corrects an already-seen event (e.g. a '
      'reconnect finalizing a chunk at an existing seq) is not treated as '
      'a no-op just because the list length is unchanged', () async {
    final fakeRepo = FakeAgentChatRepository();
    final transport = PocketcoderAgUiTransport(fakeRepo, chatId: 'c1');

    final received = <BaseEvent>[];
    final sub = transport.events.listen(received.add);

    fakeRepo.emitRawEvents([
      const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
      const TextMessageContentEvent(messageId: 'm1', delta: 'partial'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(2));

    // The cache upserts by seq: the row at the SAME position is replaced
    // with corrected content, so the list length never changes -- this is
    // exactly the "reconnect replays an existing sequence with a
    // corrected/finalized payload" scenario, not a shrink.
    fakeRepo.emitRawEvents([
      const TextMessageStartEvent(messageId: 'm1', role: TextMessageRole.assistant),
      const TextMessageContentEvent(messageId: 'm1', delta: 'final corrected text'),
    ]);
    await Future<void>.delayed(Duration.zero);

    final contentEvents = received.whereType<TextMessageContentEvent>().toList();
    expect(
      contentEvents.any((e) => e.delta == 'final corrected text'),
      isTrue,
      reason: 'the corrected content must reach downstream consumers, not '
          'be silently dropped as a same-length no-op',
    );

    await sub.cancel();
    await transport.dispose();
  });

  test('sendMessage/cancel/respondPermission delegate to the repository', () async {
    final fakeRepo = FakeAgentChatRepository();
    final transport = PocketcoderAgUiTransport(fakeRepo, chatId: 'c1');

    await transport.sendMessage('hello');
    expect(fakeRepo.sentPrompts, [('c1', 'hello')]);

    await transport.cancel();
    expect(fakeRepo.cancelledChatIds, ['c1']);

    await transport.respondPermission('p1', optionId: 'approve');
    expect(fakeRepo.permissionResponses, [('c1', 'p1', 'approve', false)]);

    await transport.dispose();
  });
}
