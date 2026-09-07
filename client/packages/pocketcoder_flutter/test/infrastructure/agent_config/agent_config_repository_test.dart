import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/agent_config/i_agent_config_repository.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/exceptions/agent_config_exception.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';
import 'package:pocketcoder_flutter/infrastructure/agent_config/agent_config_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/agent_config/agent_config_repository.dart';

class MockPocoConfigDao extends Mock implements PocoConfigDao {}

class MockPromptDao extends Mock implements PromptDao {}

class MockPermissionModeDao extends Mock implements PermissionModeDao {}

class MockAuthRepository extends Mock implements IAuthRepository {}

class _FakePocoConfig extends Fake implements PocoConfig {}

class _FakePrompt extends Fake implements Prompt {}

void main() {
  late AgentConfigRepository repo;
  late MockPocoConfigDao configDao;
  late MockPromptDao promptDao;
  late MockPermissionModeDao permissionModeDao;
  late MockAuthRepository auth;

  final testConfig = PocoConfig(
    id: 'config-1',
    name: 'Test Config',
  );

  final testPermissionMode = PermissionMode(
    id: 'mode-1',
    name: 'Balanced',
    baseSessionMode: PermissionModeBaseSessionMode.approve,
  );

  final testPrompt = Prompt(
    id: 'prompt-1',
    name: 'Test Prompt',
    body: 'hello',
  );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(_FakePocoConfig());
    registerFallbackValue(_FakePrompt());
  });

  setUp(() {
    configDao = MockPocoConfigDao();
    promptDao = MockPromptDao();
    permissionModeDao = MockPermissionModeDao();
    auth = MockAuthRepository();
    when(() => auth.currentUserId).thenReturn('user-1');
    repo = AgentConfigRepository(configDao, promptDao, permissionModeDao, auth);
  });

  test('watchConfigs forwards configDao.watch()', () {
    final stream = Stream.value([testConfig]);
    when(() => configDao.watch()).thenAnswer((_) => stream);

    expect(repo.watchConfigs(), emits([testConfig]));
    verify(() => configDao.watch()).called(1);
  });

  test('watchPrompts forwards promptDao.watch()', () {
    final stream = Stream.value([testPrompt]);
    when(() => promptDao.watch()).thenAnswer((_) => stream);

    expect(repo.watchPrompts(), emits([testPrompt]));
    verify(() => promptDao.watch()).called(1);
  });

  test('watchPermissionModes forwards permissionModeDao.watch()', () {
    final stream = Stream.value([testPermissionMode]);
    when(() => permissionModeDao.watch()).thenAnswer((_) => stream);

    expect(repo.watchPermissionModes(), emits([testPermissionMode]));
    verify(() => permissionModeDao.watch()).called(1);
  });

  test(
      'saveConfig stamps the current user onto the save payload, wraps failures in AgentConfigException',
      () async {
    when(() => configDao.save(
          any(),
          any(),
        )).thenAnswer((_) async => testConfig);

    await repo.saveConfig(testConfig);
    verify(() => configDao.save(
          testConfig.id,
          {...testConfig.toJson(), 'user': 'user-1'},
        )).called(1);

    when(() => configDao.save(any(), any())).thenThrow(Exception('boom'));
    await expectLater(
      () => repo.saveConfig(testConfig),
      throwsA(isA<AgentConfigException>()),
    );
  });

  test(
      'deleteConfig calls configDao.delete and wraps failures in AgentConfigException',
      () async {
    when(() => configDao.delete(any())).thenAnswer((_) async {});

    await repo.deleteConfig('config-1');
    verify(() => configDao.delete('config-1')).called(1);

    when(() => configDao.delete(any())).thenThrow(Exception('boom'));
    await expectLater(
      () => repo.deleteConfig('config-1'),
      throwsA(isA<AgentConfigException>()),
    );
  });

  test(
      'savePrompt stamps the current user onto the save payload, wraps failures in AgentConfigException',
      () async {
    when(() => promptDao.save(any(), any()))
        .thenAnswer((_) async => testPrompt);

    await repo.savePrompt(testPrompt);
    verify(() => promptDao.save(
          testPrompt.id,
          {...testPrompt.toJson(), 'user': 'user-1'},
        )).called(1);

    when(() => promptDao.save(any(), any())).thenThrow(Exception('boom'));
    await expectLater(
      () => repo.savePrompt(testPrompt),
      throwsA(isA<AgentConfigException>()),
    );
  });

  test(
      'deletePrompt calls promptDao.delete and wraps failures in AgentConfigException',
      () async {
    when(() => promptDao.delete(any())).thenAnswer((_) async {});

    await repo.deletePrompt('prompt-1');
    verify(() => promptDao.delete('prompt-1')).called(1);

    when(() => promptDao.delete(any())).thenThrow(Exception('boom'));
    await expectLater(
      () => repo.deletePrompt('prompt-1'),
      throwsA(isA<AgentConfigException>()),
    );
  });

  test('exposes IAgentConfigRepository methods via interface', () {
    // Compile-time-assertion-shaped smoke test: AgentConfigRepository must
    // satisfy IAgentConfigRepository so it can be registered via
    // @LazySingleton(as: IAgentConfigRepository).
    expect(repo, isA<IAgentConfigRepository>());
  });
}
