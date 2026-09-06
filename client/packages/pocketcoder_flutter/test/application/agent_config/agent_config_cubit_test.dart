import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/agent_config/agent_config_cubit.dart';
import 'package:pocketcoder_flutter/application/agent_config/agent_config_state.dart';
import 'package:pocketcoder_flutter/domain/agent_config/i_agent_config_repository.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';

class MockAgentConfigRepository extends Mock
    implements IAgentConfigRepository {}

class _FakePocoConfig extends Fake implements PocoConfig {}

class _FakePrompt extends Fake implements Prompt {}

void main() {
  late MockAgentConfigRepository repo;
  AgentConfigCubit? lastCubit;

  AgentConfigCubit buildCubit() {
    final cubit = AgentConfigCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  final testConfig = PocoConfig(
    id: 'config-1',
    name: 'Test Config',
  );

  final testPrompt = Prompt(
    id: 'prompt-1',
    name: 'Test Prompt',
    body: 'hello',
  );

  setUpAll(() {
    registerFallbackValue(_FakePocoConfig());
    registerFallbackValue(_FakePrompt());
  });

  setUp(() {
    repo = MockAgentConfigRepository();
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('AgentConfigState', () {
    test('initial() yields idle status with empty lists and no error', () {
      final state = AgentConfigState.initial();
      expect(state.isIdle, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.isFailure, isFalse);
      expect(state.hasError, isFalse);
      expect(state.configs, isEmpty);
      expect(state.prompts, isEmpty);
      expect(state.error, isNull);
    });
  });

  group('AgentConfigCubit.watchAll', () {
    test(
      'subscribe yields loading then loaded with configs and prompts',
      () async {
        final configsCtrl = StreamController<List<PocoConfig>>.broadcast();
        final promptsCtrl = StreamController<List<Prompt>>.broadcast();
        final permissionModesCtrl =
            StreamController<List<PermissionMode>>.broadcast();
        addTearDown(() async {
          await configsCtrl.close();
          await promptsCtrl.close();
          await permissionModesCtrl.close();
        });

        when(() => repo.watchConfigs()).thenAnswer((_) => configsCtrl.stream);
        when(() => repo.watchPrompts()).thenAnswer((_) => promptsCtrl.stream);
        when(() => repo.watchPermissionModes())
            .thenAnswer((_) => permissionModesCtrl.stream);

        final cubit = buildCubit();
        cubit.watchAll();

        // loading emitted synchronously on the initial emit in watchAll()
        expect(cubit.state.status, UiFlowStatus.loading);

        configsCtrl.add([testConfig]);
        promptsCtrl.add([testPrompt]);

        // Let the microtasks drain so listen() callbacks fire.
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, UiFlowStatus.success);
        expect(cubit.state.configs, [testConfig]);
        expect(cubit.state.prompts, [testPrompt]);
        expect(cubit.state.isSuccess, isTrue);
        verify(() => repo.watchConfigs()).called(1);
        verify(() => repo.watchPrompts()).called(1);
        verify(() => repo.watchPermissionModes()).called(1);
      },
    );

    test(
      'configs stream error surfaces as failure with the error in state',
      () async {
        final configsCtrl = StreamController<List<PocoConfig>>.broadcast();
        final promptsCtrl = StreamController<List<Prompt>>.broadcast();
        final permissionModesCtrl =
            StreamController<List<PermissionMode>>.broadcast();
        addTearDown(() async {
          await configsCtrl.close();
          await promptsCtrl.close();
          await permissionModesCtrl.close();
        });

        when(() => repo.watchConfigs()).thenAnswer((_) => configsCtrl.stream);
        when(() => repo.watchPrompts()).thenAnswer((_) => promptsCtrl.stream);
        when(() => repo.watchPermissionModes())
            .thenAnswer((_) => permissionModesCtrl.stream);

        final cubit = buildCubit();
        cubit.watchAll();

        configsCtrl.addError(Exception('boom'));

        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, UiFlowStatus.failure);
        expect(cubit.state.isFailure, isTrue);
        expect(cubit.state.error, isA<Exception>());
      },
    );
  });

  group('AgentConfigCubit write methods', () {
    test('saveConfig delegates to repo.saveConfig', () async {
      when(() => repo.saveConfig(any())).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.saveConfig(testConfig);

      verify(() => repo.saveConfig(testConfig)).called(1);
      expect(cubit.state.status, UiFlowStatus.success);
    });

    test('saveConfig surfaces repo failure as state error', () async {
      when(() => repo.saveConfig(any())).thenThrow(Exception('save failed'));

      final cubit = buildCubit();
      await cubit.saveConfig(testConfig);

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.isFailure, isTrue);
      expect(cubit.state.error, isA<Exception>());
    });

    test('deleteConfig delegates to repo.deleteConfig', () async {
      when(() => repo.deleteConfig(any())).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.deleteConfig('config-1');

      verify(() => repo.deleteConfig('config-1')).called(1);
      expect(cubit.state.status, UiFlowStatus.success);
    });

    test('deleteConfig surfaces repo failure as state error', () async {
      when(() => repo.deleteConfig(any()))
          .thenThrow(Exception('delete failed'));

      final cubit = buildCubit();
      await cubit.deleteConfig('config-1');

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.error, isA<Exception>());
    });

    test('savePrompt delegates to repo.savePrompt', () async {
      when(() => repo.savePrompt(any())).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.savePrompt(testPrompt);

      verify(() => repo.savePrompt(testPrompt)).called(1);
      expect(cubit.state.status, UiFlowStatus.success);
    });

    test('savePrompt surfaces repo failure as state error', () async {
      when(() => repo.savePrompt(any()))
          .thenThrow(Exception('prompt save failed'));

      final cubit = buildCubit();
      await cubit.savePrompt(testPrompt);

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.error, isA<Exception>());
    });

    test('deletePrompt delegates to repo.deletePrompt', () async {
      when(() => repo.deletePrompt(any())).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.deletePrompt('prompt-1');

      verify(() => repo.deletePrompt('prompt-1')).called(1);
      expect(cubit.state.status, UiFlowStatus.success);
    });

    test('deletePrompt surfaces repo failure as state error', () async {
      when(() => repo.deletePrompt(any()))
          .thenThrow(Exception('prompt delete failed'));

      final cubit = buildCubit();
      await cubit.deletePrompt('prompt-1');

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.error, isA<Exception>());
    });
  });
}
