// Tests for SessionControlsCubit (plan Task 12): a fake AgentChatRepository
// (no real stream/cache), asserting that SessionState.modes + .config
// surfaces in the cubit state and that selectMode/setOption call
// repository.setMode / repository.setConfigOption with the right args.
import 'dart:async';

import 'package:ag_ui/ag_ui.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:acp_dart/acp_dart.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_cubit.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';

class _FakeAgentChatRepository implements AgentChatRepository {
  final Map<String, StreamController<Conversation>> _controllers = {};
  final List<Map<String, Object?>> setModeCalls = [];
  final List<Map<String, Object?>> setConfigOptionCalls = [];

  StreamController<Conversation> controllerFor(String chatId) =>
      _controllers.putIfAbsent(chatId, () => StreamController.broadcast());

  @override
  Stream<Conversation> watch(String chatId) => controllerFor(chatId).stream;

  @override
  Stream<List<BaseEvent>> watchRawEvents(String chatId) => const Stream.empty();

  @override
  Future<int> cursorFor(String chatId) async => 0;

  @override
  Future<int> ingestOnce(String chatId, {required int cursor}) async => 0;

  @override
  Future<String> sendPrompt(String chatId, String text) async => 'run-1';

  @override
  Future<void> cancel(String chatId) async {}

  @override
  Future<void> setMode(String chatId, String modeId) async {
    setModeCalls.add({'chatId': chatId, 'modeId': modeId});
  }

  @override
  Future<void> setConfigOption(
    String chatId,
    SetSessionConfigOptionRequest req,
  ) async {
    setConfigOptionCalls.add({'chatId': chatId, 'req': req});
  }

  @override
  Future<void> respondPermission(String chatId, String requestId,
      {String? optionId, bool cancelled = false}) async {}

  @override
  Future<void> respondElicitation(
      String chatId, String elicitationId, dynamic resp) async {}
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

SessionState _modesConfigState() => SessionState(
      modes: {
        'currentModeId': 'auto',
        'availableModes': [
          {'id': 'auto', 'name': 'Auto'},
          {'id': 'chat', 'name': 'Chat'},
        ],
      },
      config: {
        'currentConfigId': 'default',
        'availableConfigs': [
          {'id': 'default', 'name': 'Default'},
        ],
      },
    );

void main() {
  late _FakeAgentChatRepository repo;
  late SessionControlsCubit cubit;

  setUp(() {
    repo = _FakeAgentChatRepository();
    cubit = SessionControlsCubit(repo);
  });

  tearDown(() async {
    await cubit.close();
  });

  test('modes + config in an emitted Conversation surface in state', () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          Conversation(sessionState: _modesConfigState()),
        );
    await _settle();

    expect(cubit.state.chatId, 'chat-1');
    expect(cubit.state.modes?['currentModeId'], 'auto');
    expect(cubit.state.config?['currentConfigId'], 'default');
    expect(cubit.state.status, UiFlowStatus.success);
  });

  test('selectMode calls repository.setMode with chatId + modeId', () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          Conversation(sessionState: _modesConfigState()),
        );
    await _settle();

    await cubit.selectMode('chat');

    expect(repo.setModeCalls, [
      {'chatId': 'chat-1', 'modeId': 'chat'},
    ]);
  });

  test(
      'selectMode does not mutate the modes map directly (effect only via stream)',
      () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          Conversation(sessionState: _modesConfigState()),
        );
    await _settle();

    final before = cubit.state.modes;

    await cubit.selectMode('chat');

    // The map is unchanged by the action itself; the next watch() emission
    // would carry the updated snapshot from the server.
    expect(cubit.state.modes, before);
    expect(repo.setModeCalls.single['modeId'], 'chat');
  });

  test('setOption calls repository.setConfigOption with chatId + req',
      () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          Conversation(sessionState: _modesConfigState()),
        );
    await _settle();

    final req = SetSessionConfigOptionRequest(
      sessionId: 'chat-1',
      configId: 'default',
      value: 'custom',
    );

    await cubit.setOption(req);

    expect(repo.setConfigOptionCalls, hasLength(1));
    expect(repo.setConfigOptionCalls.single['chatId'], 'chat-1');
    expect(repo.setConfigOptionCalls.single['req'], same(req));
  });

  test('cleared modes/config (null) in a later emission clears state',
      () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          Conversation(sessionState: _modesConfigState()),
        );
    await _settle();
    expect(cubit.state.modes?['currentModeId'], 'auto');

    repo.controllerFor('chat-1').add(
          Conversation(sessionState: SessionState.empty),
        );
    await _settle();

    expect(cubit.state.modes, isNull);
    expect(cubit.state.config, isNull);
  });
}
