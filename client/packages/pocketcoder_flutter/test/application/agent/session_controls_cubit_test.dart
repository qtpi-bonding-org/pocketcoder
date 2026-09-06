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
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_cubit.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/agent_config/agent_config_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/chat/chat_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/provider/provider_daos.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart' as domain_model;
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;

class MockChatDao extends Mock implements ChatDao {}

class MockPocoConfigDao extends Mock implements PocoConfigDao {}

class MockPermissionModeDao extends Mock implements PermissionModeDao {}

class MockHarnessModelDao extends Mock implements HarnessModelDao {}

class MockHarnesseDao extends Mock implements HarnesseDao {}

class MockModelDao extends Mock implements ModelDao {}

class MockProviderCatalogDao extends Mock implements ProviderCatalogDao {}

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

/// Matches config_picker.dart's shape: an "options" list of maps with
/// `id`/`currentValue`, not the `_modesConfigState` fixture's shape above.
SessionState _idleConfigWithActiveProvider(String providerId) => SessionState(
      config: {
        'options': [
          {'id': 'provider', 'kind': 'select', 'currentValue': providerId},
          {'id': 'model', 'kind': 'select', 'currentValue': 'placeholder'},
        ],
      },
      isRunning: false,
    );

void main() {
  late _FakeAgentChatRepository repo;
  late MockChatDao chatDao;
  late MockPocoConfigDao pocoConfigDao;
  late MockPermissionModeDao permissionModeDao;
  late MockHarnessModelDao harnessModelDao;
  late MockHarnesseDao harnesseDao;
  late MockModelDao modelDao;
  late MockProviderCatalogDao providerCatalogDao;
  late SessionControlsCubit cubit;

  setUp(() {
    repo = _FakeAgentChatRepository();
    chatDao = MockChatDao();
    pocoConfigDao = MockPocoConfigDao();
    permissionModeDao = MockPermissionModeDao();
    harnessModelDao = MockHarnessModelDao();
    harnesseDao = MockHarnesseDao();
    modelDao = MockModelDao();
    providerCatalogDao = MockProviderCatalogDao();
    // .pb is used purely for its .filter() string helper (no network) --
    // stub it with a real, unconnected PocketBase instance so the idle
    // paths below can build a parameterized filter safely.
    when(() => permissionModeDao.pb).thenReturn(PocketBase('http://localhost'));
    when(() => harnessModelDao.pb).thenReturn(PocketBase('http://localhost'));
    cubit = SessionControlsCubit(repo, chatDao, pocoConfigDao,
        permissionModeDao, harnessModelDao, harnesseDao, modelDao, providerCatalogDao);
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

  test('idle setOption persists a known chat override as a JSON array',
      () async {
    // workspace_override is a PocketBase JSON field the server unmarshals
    // into []string (sessionprofile.go, using element 0 as cwd) -- writing
    // the raw scalar value there is silently ignored server-side.
    when(() => chatDao.save('chat-1', {
          'workspace_override': ['/tmp/workspace']
        })).thenAnswer(
      (_) async => throw UnimplementedError(),
    );

    cubit.open('chat-1');
    await _settle();
    await cubit.setOption(SetSessionConfigOptionRequest(
      sessionId: 'chat-1',
      configId: 'workspaceOverride',
      value: '/tmp/workspace',
    ));

    verify(() => chatDao.save('chat-1', {
          'workspace_override': ['/tmp/workspace']
        })).called(1);
    expect(repo.setConfigOptionCalls, isEmpty);
  });

  test('idle setOption clears the workspace override on an empty value',
      () async {
    when(() => chatDao.save('chat-1', {'workspace_override': <String>[]}))
        .thenAnswer(
      (_) async => throw UnimplementedError(),
    );

    cubit.open('chat-1');
    await _settle();
    await cubit.setOption(SetSessionConfigOptionRequest(
      sessionId: 'chat-1',
      configId: 'workspaceOverride',
      value: '',
    ));

    verify(() => chatDao.save('chat-1', {'workspace_override': <String>[]}))
        .called(1);
  });

  test(
      'idle unknown config option surfaces as a failure state instead of '
      'throwing', () async {
    // Every setOption failure must be caught by tryOperation and surfaced
    // in state, never left to escape as an unhandled exception.
    cubit.open('chat-1');
    await _settle();

    await cubit.setOption(SetSessionConfigOptionRequest(
      sessionId: 'chat-1',
      configId: 'unknown',
      value: 'value',
    ));

    expect(cubit.state.status, UiFlowStatus.failure);
    expect(cubit.state.error, isA<UnsupportedError>());
    expect(repo.setConfigOptionCalls, isEmpty);
  });

  test(
      'running setOption for configId "model" still forwards live via '
      'repository (unaffected by the idle catalog lookup)', () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          Conversation(sessionState: _modesConfigState(isRunning: true)),
        );
    await _settle();

    final req = SetSessionConfigOptionRequest(
      sessionId: 'chat-1',
      configId: 'model',
      value: 'anthropic/claude-sonnet-4-5',
    );

    await cubit.setOption(req);

    expect(repo.setConfigOptionCalls, hasLength(1));
    expect(repo.setConfigOptionCalls.single['req'], same(req));
    verifyNever(() => chatDao.save(any(), any()));
    verifyNever(() => harnessModelDao.getFullList(filter: any(named: 'filter')));
    verifyNever(() => harnesseDao.getOne(any()));
  });

  const chatWithHarness = Chat(
    id: 'chat-1',
    title: 'Chat',
    user: 'user-1',
    harness: 'harness-1',
  );
  const ollamaHarness = Harnesse(
    id: 'harness-1',
    name: 'Goose',
    cliId: 'goose',
    acpTransport: HarnesseAcpTransport.stdio,
    supportsOllama: true,
  );
  const nonOllamaHarness = Harnesse(
    id: 'harness-1',
    name: 'Claude Code',
    cliId: 'claude-code',
    acpTransport: HarnesseAcpTransport.stdio,
    supportsOllama: false,
  );

  test(
      'idle setOption for configId "model" persists the matching '
      'harness_models catalog row as harness_model_override, clearing any '
      'stale ollama_model_override', () async {
    when(() => chatDao.getOne('chat-1'))
        .thenAnswer((_) async => chatWithHarness);
    when(() => harnessModelDao.getFullList(
            filter: 'harness = "harness-1" && '
                'harness_model_id = "anthropic/claude-sonnet-4-5"'))
        .thenAnswer((_) async => const [
              HarnessModel(
                id: 'hm-sonnet',
                harness: 'harness-1',
                model: 'model-rec-1',
                harnessModelId: 'anthropic/claude-sonnet-4-5',
              ),
            ]);
    when(() => chatDao.save('chat-1', {
          'harness_model_override': 'hm-sonnet',
          'ollama_model_override': '',
        })).thenAnswer((_) async => chatWithHarness);

    cubit.open('chat-1');
    await _settle();
    await cubit.setOption(SetSessionConfigOptionRequest(
      sessionId: 'chat-1',
      configId: 'model',
      value: 'anthropic/claude-sonnet-4-5',
    ));

    verify(() => chatDao.save('chat-1', {
          'harness_model_override': 'hm-sonnet',
          'ollama_model_override': '',
        })).called(1);
    expect(cubit.state.status, UiFlowStatus.success);
    expect(repo.setConfigOptionCalls, isEmpty);
    verifyNever(() => harnesseDao.getOne(any()));
    // A single unambiguous catalog match needs no provider disambiguation.
    verifyNever(() => modelDao.getOne(any()));
    verifyNever(() => providerCatalogDao.getOne(any()));
  });

  test(
      'idle setOption for configId "model" picks the harness_models row '
      'whose provider matches the session\'s currently active provider, '
      'not just the first duplicate returned by the catalog filter',
      () async {
    // Two harness_models rows share this harness_model_id (provider
    // fanout); the wrong one has no credentials configured here.
    when(() => chatDao.getOne('chat-1'))
        .thenAnswer((_) async => chatWithHarness);
    when(() => harnessModelDao.getFullList(
            filter: 'harness = "harness-1" && '
                'harness_model_id = "anthropic/claude-sonnet-4.5"'))
        .thenAnswer((_) async => const [
              HarnessModel(
                id: 'hm-orca',
                harness: 'harness-1',
                model: 'model-orca',
                harnessModelId: 'anthropic/claude-sonnet-4.5',
              ),
              HarnessModel(
                id: 'hm-openrouter',
                harness: 'harness-1',
                model: 'model-openrouter',
                harnessModelId: 'anthropic/claude-sonnet-4.5',
              ),
            ]);
    when(() => modelDao.getOne('model-orca')).thenAnswer((_) async =>
        const domain_model.Model(
            id: 'model-orca', name: 'Claude Sonnet 4.5', provider: 'prov-orca'));
    when(() => modelDao.getOne('model-openrouter')).thenAnswer((_) async =>
        const domain_model.Model(
            id: 'model-openrouter',
            name: 'Claude Sonnet 4.5',
            provider: 'prov-openrouter'));
    when(() => providerCatalogDao.getOne('prov-orca')).thenAnswer((_) async =>
        const domain.Provider(
            id: 'prov-orca', providerId: 'orcarouter', name: 'OrcaRouter'));
    when(() => providerCatalogDao.getOne('prov-openrouter')).thenAnswer(
        (_) async => const domain.Provider(
            id: 'prov-openrouter', providerId: 'openrouter', name: 'OpenRouter'));
    when(() => chatDao.save('chat-1', {
          'harness_model_override': 'hm-openrouter',
          'ollama_model_override': '',
        })).thenAnswer((_) async => chatWithHarness);

    cubit.open('chat-1');
    await _settle();
    repo.controllerFor('chat-1').add(
          Conversation(sessionState: _idleConfigWithActiveProvider('openrouter')),
        );
    await _settle();

    await cubit.setOption(SetSessionConfigOptionRequest(
      sessionId: 'chat-1',
      configId: 'model',
      value: 'anthropic/claude-sonnet-4.5',
    ));

    verify(() => chatDao.save('chat-1', {
          'harness_model_override': 'hm-openrouter',
          'ollama_model_override': '',
        })).called(1);
    verifyNever(() => chatDao.save('chat-1', {
          'harness_model_override': 'hm-orca',
          'ollama_model_override': '',
        }));
    expect(cubit.state.status, UiFlowStatus.success);
  });

  test(
      'idle setOption for configId "model" falls back to the first catalog '
      'match when no active provider can be determined from session state',
      () async {
    when(() => chatDao.getOne('chat-1'))
        .thenAnswer((_) async => chatWithHarness);
    when(() => harnessModelDao.getFullList(
            filter: 'harness = "harness-1" && '
                'harness_model_id = "anthropic/claude-sonnet-4.5"'))
        .thenAnswer((_) async => const [
              HarnessModel(
                id: 'hm-orca',
                harness: 'harness-1',
                model: 'model-orca',
                harnessModelId: 'anthropic/claude-sonnet-4.5',
              ),
              HarnessModel(
                id: 'hm-openrouter',
                harness: 'harness-1',
                model: 'model-openrouter',
                harnessModelId: 'anthropic/claude-sonnet-4.5',
              ),
            ]);
    when(() => chatDao.save('chat-1', {
          'harness_model_override': 'hm-orca',
          'ollama_model_override': '',
        })).thenAnswer((_) async => chatWithHarness);

    // state.sessionState.config is still null -- no provider signal exists.
    cubit.open('chat-1');
    await _settle();
    await cubit.setOption(SetSessionConfigOptionRequest(
      sessionId: 'chat-1',
      configId: 'model',
      value: 'anthropic/claude-sonnet-4.5',
    ));

    verify(() => chatDao.save('chat-1', {
          'harness_model_override': 'hm-orca',
          'ollama_model_override': '',
        })).called(1);
    expect(cubit.state.status, UiFlowStatus.success);
    verifyNever(() => modelDao.getOne(any()));
    verifyNever(() => providerCatalogDao.getOne(any()));
  });

  test(
      'idle setOption for configId "model" falls back to '
      'ollama_model_override when no catalog row matches and the chat\'s '
      'harness supports Ollama, clearing any stale harness_model_override',
      () async {
    when(() => chatDao.getOne('chat-1'))
        .thenAnswer((_) async => chatWithHarness);
    when(() => harnessModelDao.getFullList(
            filter: 'harness = "harness-1" && '
                'harness_model_id = "llama3"'))
        .thenAnswer((_) async => const []);
    when(() => harnesseDao.getOne('harness-1'))
        .thenAnswer((_) async => ollamaHarness);
    when(() => chatDao.save('chat-1', {
          'ollama_model_override': 'llama3',
          'harness_model_override': '',
        })).thenAnswer((_) async => chatWithHarness);

    cubit.open('chat-1');
    await _settle();
    await cubit.setOption(SetSessionConfigOptionRequest(
      sessionId: 'chat-1',
      configId: 'model',
      value: 'llama3',
    ));

    verify(() => chatDao.save('chat-1', {
          'ollama_model_override': 'llama3',
          'harness_model_override': '',
        })).called(1);
    expect(cubit.state.status, UiFlowStatus.success);
    expect(repo.setConfigOptionCalls, isEmpty);
  });

  test(
      'idle setOption for configId "model" fails gracefully -- rather than '
      'silently persisting a bogus Ollama override -- when no catalog row '
      'matches and the chat\'s harness does not support Ollama', () async {
    when(() => chatDao.getOne('chat-1'))
        .thenAnswer((_) async => chatWithHarness);
    when(() => harnessModelDao.getFullList(
            filter: 'harness = "harness-1" && '
                'harness_model_id = "not-a-real-model"'))
        .thenAnswer((_) async => const []);
    when(() => harnesseDao.getOne('harness-1'))
        .thenAnswer((_) async => nonOllamaHarness);

    cubit.open('chat-1');
    await _settle();
    await cubit.setOption(SetSessionConfigOptionRequest(
      sessionId: 'chat-1',
      configId: 'model',
      value: 'not-a-real-model',
    ));

    expect(cubit.state.status, UiFlowStatus.failure);
    expect(cubit.state.error, isA<StateError>());
    verifyNever(() => chatDao.save(any(), any()));
  });

  test(
      'idle setOption for configId "model" fails gracefully when the chat '
      'has no harness to resolve the catalog lookup against', () async {
    when(() => chatDao.getOne('chat-1')).thenAnswer((_) async => const Chat(
          id: 'chat-1',
          title: 'Chat',
          user: 'user-1',
        ));

    cubit.open('chat-1');
    await _settle();
    await cubit.setOption(SetSessionConfigOptionRequest(
      sessionId: 'chat-1',
      configId: 'model',
      value: 'anthropic/claude-sonnet-4-5',
    ));

    expect(cubit.state.status, UiFlowStatus.failure);
    expect(cubit.state.error, isA<StateError>());
    verifyNever(() => harnessModelDao.getFullList(filter: any(named: 'filter')));
    verifyNever(() => harnesseDao.getOne(any()));
    verifyNever(() => chatDao.save(any(), any()));
  });

  test(
      'idle setOption for configId "model" fails gracefully on an empty '
      'value instead of persisting a blank Ollama override', () async {
    when(() => chatDao.getOne('chat-1'))
        .thenAnswer((_) async => chatWithHarness);

    cubit.open('chat-1');
    await _settle();
    await cubit.setOption(SetSessionConfigOptionRequest(
      sessionId: 'chat-1',
      configId: 'model',
      value: '',
    ));

    expect(cubit.state.status, UiFlowStatus.failure);
    expect(cubit.state.error, isA<StateError>());
    verifyNever(() => harnessModelDao.getFullList(filter: any(named: 'filter')));
    verifyNever(() => chatDao.save(any(), any()));
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
