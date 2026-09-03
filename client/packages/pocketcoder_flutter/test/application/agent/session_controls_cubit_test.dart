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
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_cubit.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/agent_config/agent_config_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/chat/chat_dao.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';

class MockChatDao extends Mock implements ChatDao {}

class MockPocoConfigDao extends Mock implements PocoConfigDao {}

class MockPermissionModeDao extends Mock implements PermissionModeDao {}

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
  Future<void> cancelStreams() async {}

  @override
  Future<String> sendPrompt(String chatId, String text,
          {String? messageId}) async =>
      'run-1';

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

SessionState _modesConfigState({bool isRunning = false}) => SessionState(
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
      isRunning: isRunning,
    );

void main() {
  late _FakeAgentChatRepository repo;
  late MockChatDao chatDao;
  late MockPocoConfigDao pocoConfigDao;
  late MockPermissionModeDao permissionModeDao;
  late SessionControlsCubit cubit;

  setUp(() {
    repo = _FakeAgentChatRepository();
    chatDao = MockChatDao();
    pocoConfigDao = MockPocoConfigDao();
    permissionModeDao = MockPermissionModeDao();
    cubit =
        SessionControlsCubit(repo, chatDao, pocoConfigDao, permissionModeDao);
  });

  tearDown(() async {
    await cubit.close();
  });

  test('modes + config in an emitted Conversation surface in state', () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          Conversation(sessionState: _modesConfigState(isRunning: true)),
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
          Conversation(sessionState: _modesConfigState(isRunning: true)),
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
          Conversation(sessionState: _modesConfigState(isRunning: true)),
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
          Conversation(sessionState: _modesConfigState(isRunning: true)),
        );
    await _settle();

    final req = SetSessionConfigOptionRequest(
      sessionId: 'chat-1',
      configId: 'harnessModelOverride',
      value: 'custom',
    );

    await cubit.setOption(req);

    expect(repo.setConfigOptionCalls, hasLength(1));
    expect(repo.setConfigOptionCalls.single['chatId'], 'chat-1');
    expect(repo.setConfigOptionCalls.single['req'], same(req));
  });

  test('idle selectMode persists the permission mode on the agent profile',
      () async {
    final chat = Chat(
      id: 'chat-1',
      title: 'Chat',
      user: 'user-1',
      agentProfile: 'profile-1',
    );
    final mode = PermissionMode(
      id: 'permission-1',
      name: 'Chat',
      baseSessionMode: PermissionModeBaseSessionMode.chat,
    );
    when(() => chatDao.getOne('chat-1')).thenAnswer((_) async => chat);
    when(() =>
            permissionModeDao.getFullList(filter: 'base_session_mode = "chat"'))
        .thenAnswer((_) async => [mode]);
    when(() => pocoConfigDao
        .save('profile-1', {'permission_mode': 'permission-1'})).thenAnswer(
      (_) async => throw UnimplementedError(),
    );

    cubit.open('chat-1');
    await _settle();
    await cubit.selectMode('chat');

    verify(() => pocoConfigDao
        .save('profile-1', {'permission_mode': 'permission-1'})).called(1);
    expect(repo.setModeCalls, isEmpty);
  });

  test('idle setOption persists a known chat override', () async {
    when(() => chatDao.save('chat-1', {'workspace_override': '/tmp/workspace'}))
        .thenAnswer(
      (_) async => throw UnimplementedError(),
    );

    cubit.open('chat-1');
    await _settle();
    await cubit.setOption(SetSessionConfigOptionRequest(
      sessionId: 'chat-1',
      configId: 'workspaceOverride',
      value: '/tmp/workspace',
    ));

    verify(() =>
            chatDao.save('chat-1', {'workspace_override': '/tmp/workspace'}))
        .called(1);
    expect(repo.setConfigOptionCalls, isEmpty);
  });

  test('idle unknown config option throws UnsupportedError', () async {
    cubit.open('chat-1');
    await _settle();

    await expectLater(
      cubit.setOption(SetSessionConfigOptionRequest(
        sessionId: 'chat-1',
        configId: 'unknown',
        value: 'value',
      )),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('cleared modes/config (null) in a later emission clears state',
      () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          Conversation(sessionState: _modesConfigState(isRunning: true)),
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
