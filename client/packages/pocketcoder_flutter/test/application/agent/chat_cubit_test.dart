// Tests for ChatCubit (plan Task 11): a fake AgentChatRepository (no real
// stream/cache), asserting the reduce-and-emit contract, that actions never
// mutate state directly, and that reconnect uses the repository's cursor.
import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/agent/chat_cubit.dart';
import 'package:pocketcoder_flutter/domain/agent/conversation.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';

/// Minimal fake standing in for AgentChatRepository: `watch` is driven by a
/// per-chat StreamController the test controls directly; `ingestOnce`
/// completes immediately (so the cubit's reconnect loop just spins,
/// harmlessly, without a real connection) and records every call's cursor
/// via [cursorForCalls]/[ingestCalls] so tests can assert on the reconnect
/// contract without a real stream client.
class _FakeAgentChatRepository implements AgentChatRepository {
  final Map<String, StreamController<Conversation>> _controllers = {};
  final List<String> promptCalls = [];
  final List<int> cursorForCalls = [];
  final List<int> ingestCalls = [];
  int _nextCursor = 0;

  StreamController<Conversation> controllerFor(String chatId) =>
      _controllers.putIfAbsent(chatId, () => StreamController.broadcast());

  void setNextCursor(int cursor) => _nextCursor = cursor;

  @override
  Stream<Conversation> watch(String chatId) => controllerFor(chatId).stream;

  @override
  Future<int> cursorFor(String chatId) async {
    cursorForCalls.add(_nextCursor);
    return _nextCursor;
  }

  @override
  Future<void> ingestOnce(String chatId, {required int cursor}) async {
    ingestCalls.add(cursor);
    // Complete immediately — the cubit's while-loop will call cursorFor/
    // ingestOnce again, so tests bound iterations by awaiting a
    // pumpEventQueue then asserting on the recorded call lists, not by
    // letting this run forever uncontrolled.
    return;
  }

  @override
  Future<String> sendPrompt(String chatId, String text) async {
    promptCalls.add(text);
    return 'run-123';
  }

  @override
  Future<void> cancel(String chatId) async {}

  @override
  Future<void> setMode(String chatId, String modeId) async {}

  @override
  Future<void> setConfigOption(String chatId, dynamic req) async {}

  @override
  Future<void> respondPermission(String chatId, String requestId,
      {String? optionId, bool cancelled = false}) async {}

  @override
  Future<void> respondElicitation(
      String chatId, String elicitationId, dynamic resp) async {}
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeAgentChatRepository repo;
  late ChatCubit cubit;

  setUp(() {
    repo = _FakeAgentChatRepository();
    cubit = ChatCubit(repo);
  });

  tearDown(() async {
    await cubit.close();
  });

  test('open() emits ChatState reduced from the watched Conversation',
      () async {
    cubit.open('chat-1');
    await _settle();

    final conversation = Conversation(
      timeline: const [
        TimelineItem.text(id: 'm1', kind: ChatMessageKind.text, role: 'assistant', text: 'hi'),
      ],
      sessionState: SessionState.empty,
    );
    repo.controllerFor('chat-1').add(conversation);
    await _settle();

    expect(cubit.state.chatId, 'chat-1');
    expect(cubit.state.conversation.timeline, hasLength(1));
    expect(cubit.state.status, UiFlowStatus.success);
  });

  test('sendPrompt calls the repository and does not mutate conversation '
      'directly (effect only arrives via the watched stream)', () async {
    cubit.open('chat-1');
    await _settle();

    await cubit.sendPrompt('hello agent');

    expect(repo.promptCalls, ['hello agent']);
    // No direct mutation: sendPrompt alone (with no stream emission) leaves
    // the conversation exactly where watch() left it — empty, since the
    // fake never pushed a Conversation in this test.
    expect(cubit.state.conversation, Conversation.empty);
  });

  test('the ingest loop reconnects using cursorFor as the cursor', () async {
    repo.setNextCursor(42);
    cubit.open('chat-1');
    // The first attempt runs immediately (no delay before it); the cubit
    // waits a short real delay between reconnect attempts (so a fake that
    // completes instantly can't busy-loop and starve the event loop —
    // exercised implicitly here by simply waiting past one such delay).
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repo.cursorForCalls, isNotEmpty);
    expect(repo.cursorForCalls.first, 42);
    expect(repo.ingestCalls, isNotEmpty);
    expect(repo.ingestCalls.first, 42);
  });
}
