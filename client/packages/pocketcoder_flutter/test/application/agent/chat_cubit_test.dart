// Tests for ChatCubit (plan Task 11): a fake AgentChatRepository (no real
// stream/cache), asserting the reduce-and-emit contract, that actions never
// mutate local state directly, and that reconnect uses the repository's cursor.
import 'dart:async';

import 'package:ag_ui/ag_ui.dart' as agui;
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart'
    as agui_widgets;
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:pocketcoder_flutter/application/agent/chat_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/chat_state.dart';
import 'package:pocketcoder_flutter/application/agent/seen_messages_registry.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_actions_api.dart'
    show AgentUnavailableFailure;
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/network_recovery_signal.dart';
import 'package:pocketcoder_flutter/domain/chat/i_chat_list_repository.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';

class FakeChatListRepository implements IChatListRepository {
  final Map<String, ({String text, ChatTurn turn, bool isFirst})> _recorded =
      {};

  ({String text, ChatTurn turn, bool isFirst})? lastRecorded(String chatId) =>
      _recorded[chatId];

  @override
  Future<void> recordMessagePreview(String chatId,
      {required String text,
      required ChatTurn turn,
      required bool isFirst}) async {
    _recorded[chatId] = (
      text: text,
      turn: turn,
      isFirst: isFirst,
    );
  }

  @override
  Stream<List<Chat>> watchChats() => const Stream.empty();

  @override
  Future<bool> hasAnyChats() async => false;

  @override
  Future<Chat> createChat({
    String? title,
    String? harness,
    String? harnessModelOverride,
    String? ollamaModelOverride,
    List<String>? workspaceOverride,
  }) async =>
      const Chat(id: 'fake', title: 'fake', user: 'fake');

  @override
  Future<void> archiveChat(String id) async {}

  @override
  Future<void> deleteChat(String id) async {}

  @override
  Stream<Chat?> watchChat(String id) => const Stream.empty();

  @override
  Future<void> setMonitored(String id, bool monitored) async {}
}

/// Minimal fake standing in for AgentChatRepository: `watchRawEvents` is driven by a
/// per-chat StreamController the test controls directly; `ingestOnce`
/// completes immediately (so the cubit's reconnect loop just spins,
/// harmlessly, without a real connection) and records every call's cursor
/// via [cursorForCalls]/[ingestCalls] so tests can assert on the reconnect
/// contract without a real stream client.
class _FakeAgentChatRepository implements AgentChatRepository {
  final Map<String, StreamController<List<agui.BaseEvent>>> _controllers = {};
  final List<String> promptCalls = [];
  final List<String?> promptMessageIds = [];
  final List<int> cursorForCalls = [];
  final List<int> ingestCalls = [];
  int _nextCursor = 0;
  int cancelStreamsCalls = 0;
  Completer<void>? _sendPromptGate;

  StreamController<List<agui.BaseEvent>> controllerFor(String chatId) =>
      _controllers.putIfAbsent(chatId, () => StreamController.broadcast());

  void setNextCursor(int cursor) => _nextCursor = cursor;

  /// Lets a test hold `sendPrompt` pending until it explicitly releases it,
  /// to simulate a slow network round-trip that resolves after the user has
  /// already moved on to a different chat.
  Completer<void> gateSendPrompt() {
    final gate = Completer<void>();
    _sendPromptGate = gate;
    return gate;
  }

  @override
  Stream<List<agui.BaseEvent>> watchRawEvents(String chatId) =>
      controllerFor(chatId).stream;

  @override
  Stream<agui_widgets.Conversation> watch(String chatId) =>
      const Stream.empty();

  @override
  Future<int> cursorFor(String chatId) async {
    cursorForCalls.add(_nextCursor);
    return _nextCursor;
  }

  @override
  Future<int> ingestOnce(String chatId, {required int cursor}) async {
    ingestCalls.add(cursor);
    // Complete immediately — the cubit's while-loop will call cursorFor/
    // ingestOnce again, so tests bound iterations by awaiting a
    // pumpEventQueue then asserting on the recorded call lists, not by
    // letting this run forever uncontrolled.
    return 0;
  }

  int failWithHarnessUnavailableTimes = 0;

  @override
  Future<String> sendPrompt(String chatId, String text,
      {String? messageId}) async {
    promptCalls.add(text);
    promptMessageIds.add(messageId);
    final gate = _sendPromptGate;
    if (gate != null) await gate.future;
    if (failWithHarnessUnavailableTimes > 0) {
      failWithHarnessUnavailableTimes--;
      throw const AgentUnavailableFailure('Harness is starting; retry '
          'shortly.');
    }
    return 'run-123';
  }

  @override
  Future<void> cancel(String chatId) async {}

  @override
  Future<void> cancelStreams() async {
    cancelStreamsCalls++;
  }

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
  late FakeChatListRepository fakeChatListRepository;
  late SeenMessagesRegistry seenMessages;
  late ChatCubit cubit;

  setUp(() {
    repo = _FakeAgentChatRepository();
    fakeChatListRepository = FakeChatListRepository();
    seenMessages = SeenMessagesRegistry();
    cubit = ChatCubit(
      repo,
      NetworkRecoverySignal(),
      fakeChatListRepository,
      seenMessages,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  test('open() emits ChatState reduced from raw events', () async {
    cubit.open('chat-1');
    await _settle();

    // Emit real text message events. The ConversationReducer will reduce
    // these into a Conversation with a populated timeline.
    final events = [
      const agui.TextMessageStartEvent(
        messageId: 'm1',
        role: agui.TextMessageRole.assistant,
      ),
      const agui.TextMessageContentEvent(messageId: 'm1', delta: 'Hello, '),
      const agui.TextMessageContentEvent(messageId: 'm1', delta: 'world!'),
      const agui.TextMessageEndEvent(messageId: 'm1'),
    ];
    repo.controllerFor('chat-1').add(events);
    await _settle();

    expect(cubit.state.chatId, 'chat-1');
    expect(cubit.state.status, UiFlowStatus.success);
    // Assert the reducer populated the timeline correctly.
    expect(cubit.state.conversation.timeline, hasLength(1));
    final item = cubit.state.conversation.timeline.single;
    expect(item, isA<agui_widgets.TextTimelineItem>());
    expect((item as agui_widgets.TextTimelineItem).text, 'Hello, world!');
  });

  test(
      'a message is marked animated the instant its stream ends, before '
      'it is ever rendered as completed', () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add([
      const agui.TextMessageStartEvent(
        messageId: 'poco-1',
        role: agui.TextMessageRole.assistant,
      ),
      const agui.TextMessageContentEvent(
        messageId: 'poco-1',
        delta: 'hello there',
      ),
      const agui.TextMessageEndEvent(messageId: 'poco-1'),
    ]);
    await _settle();

    expect(cubit.state.animatedMessageIds, contains('poco-1'));
    expect(seenMessages.hasSeen('chat-1', 'poco-1'), isTrue);
  });

  test(
      'sendPrompt optimistically inserts the user\'s message into the '
      'conversation immediately, before any event arrives', () async {
    cubit.open('chat-1');
    await _settle();

    await cubit.sendPrompt('hello agent');

    expect(repo.promptCalls, ['hello agent']);
    expect(cubit.state.conversation.timeline, hasLength(1));
    final item = cubit.state.conversation.timeline.single
        as agui_widgets.TextTimelineItem;
    expect(item.role, 'user');
    expect(item.text, 'hello agent');
  });

  test('sendPrompt records the user message as the chat preview, marking '
      'the very first message as isFirst', () async {
    cubit.open('chat-1');
    await pumpEventQueue();

    await cubit.sendPrompt('hello there');

    expect(fakeChatListRepository.lastRecorded('chat-1'),
        (text: 'hello there', turn: ChatTurn.user, isFirst: true));

    await cubit.sendPrompt('a second message');

    expect(fakeChatListRepository.lastRecorded('chat-1'),
        (text: 'a second message', turn: ChatTurn.user, isFirst: false));
  });

  test('a completed Poco reply records the chat preview as assistant turn, '
      'never as isFirst', () async {
    cubit.open('chat-1');
    await pumpEventQueue();

    repo.controllerFor('chat-1').add([
      const agui.TextMessageStartEvent(
        messageId: 'poco-1',
        role: agui.TextMessageRole.assistant,
      ),
      const agui.TextMessageContentEvent(
        messageId: 'poco-1',
        delta: 'hi yourself',
      ),
      const agui.TextMessageEndEvent(messageId: 'poco-1'),
    ]);
    await pumpEventQueue();

    expect(fakeChatListRepository.lastRecorded('chat-1'),
        (text: 'hi yourself', turn: ChatTurn.assistant, isFirst: false));
  });

  test(
      'sendPrompt auto-retries on AgentUnavailableFailure and shows '
      'awaitingHarnessStart until it succeeds, without duplicating the '
      'optimistic local echo', () async {
    cubit.open('chat-1');
    await _settle();
    repo.failWithHarnessUnavailableTimes = 1;

    final send = cubit.sendPrompt('hello agent');
    await pumpEventQueue();

    expect(cubit.state.awaitingHarnessStart, isTrue);
    expect(cubit.state.status, UiFlowStatus.loading);

    await send;

    expect(repo.promptCalls, ['hello agent', 'hello agent'],
        reason: 'the first (failing) attempt and the retry both call '
            'sendPrompt with the same text');
    expect(repo.promptMessageIds.toSet(), hasLength(1),
        reason: 'the retry must reuse the same optimistic message id, not '
            'mint a new one');
    expect(cubit.state.awaitingHarnessStart, isFalse);
    expect(cubit.state.status, UiFlowStatus.success);
    expect(cubit.state.conversation.timeline, hasLength(1),
        reason: 'the optimistic local echo must be inserted exactly once, '
            'not once per retry attempt');
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('markMessageAnimated adds the id once and is idempotent', () async {
    cubit.open('chat-1');
    await _settle();

    cubit.markMessageAnimated('msg-1');
    expect(cubit.state.animatedMessageIds, {'msg-1'});

    cubit.markMessageAnimated('msg-1');
    expect(cubit.state.animatedMessageIds, {'msg-1'});
  });

  test(
      'a locally-inserted user message is superseded, not duplicated, if '
      'the backend later echoes a real event for the same run', () async {
    cubit.open('chat-1');
    await _settle();
    await cubit.sendPrompt('hello agent');

    final localId = (cubit.state.conversation.timeline.single
            as agui_widgets.TextTimelineItem)
        .id;
    repo.controllerFor('chat-1').add([
      agui.TextMessageStartEvent(
          messageId: localId, role: agui.TextMessageRole.user),
      agui.TextMessageContentEvent(messageId: localId, delta: 'hello agent'),
      agui.TextMessageEndEvent(messageId: localId),
    ]);
    await _settle();

    expect(cubit.state.conversation.timeline, hasLength(1));
  });

  test(
      'a sendPrompt that resolves after the user has switched chats does '
      "not stomp the new chat's state", () async {
    cubit.open('chat-1');
    await _settle();

    final gate = repo.gateSendPrompt();
    final send = cubit.sendPrompt('slow message for chat-1');
    // sendPrompt is now pending inside the repository call, gated open.

    cubit.open('chat-2');
    await _settle();
    expect(cubit.state.chatId, 'chat-2');
    expect(cubit.state.lastOperation, AgentChatOperation.open);

    // Now let chat-1's send resolve, well after the switch. Chat-2 hasn't
    // received any events yet, so its status is still loading -- a stale
    // sendPrompt success must not flip it to success/sendPrompt.
    gate.complete();
    await send;
    await _settle();

    expect(cubit.state.chatId, 'chat-2');
    expect(cubit.state.lastOperation, AgentChatOperation.open,
        reason: "chat-1's late-resolving sendPrompt must not overwrite "
            "chat-2's lastOperation");
    expect(cubit.state.status, UiFlowStatus.loading,
        reason: "chat-1's late-resolving sendPrompt must not flip "
            "chat-2's status to success");
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

  test('close cancels the active ingest stream', () async {
    cubit.open('chat-1');
    // open() tears down any connection left by a prior chat. Ignore that
    // initial no-op teardown and verify close() performs its own cancellation.
    repo.cancelStreamsCalls = 0;
    await cubit.close();

    expect(repo.cancelStreamsCalls, 1);
  });

  test(
      'sendPrompt uses a real UUID for the optimistic message id, and sends '
      'the same id to the server', () async {
    cubit.open('chat-1');
    await _settle();

    await cubit.sendPrompt('hello agent');

    final item = cubit.state.conversation.timeline.single
        as agui_widgets.TextTimelineItem;
    expect(Uuid.isValidUUID(fromString: item.id), isTrue);
    expect(repo.promptMessageIds, [item.id]);
  });
}
