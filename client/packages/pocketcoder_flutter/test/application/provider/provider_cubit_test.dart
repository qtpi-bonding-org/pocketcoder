import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';

class MockProviderRepository extends Mock implements IProviderRepository {}

class _FakeProviderApiKey extends Fake implements ProviderApiKey {}

void main() {
  late MockProviderRepository repo;
  ProviderCubit? lastCubit;

  ProviderCubit buildCubit() {
    final cubit = ProviderCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  final testHarnesse = Harnesse(
    id: 'h-1',
    name: 'Test Harnesse',
    cliId: 'cli-1',
    acpTransport: HarnesseAcpTransport.websocket,
  );

  final testModel = Model(
    id: 'm-1',
    name: 'Test Model',
    provider: 'anthropic',
  );

  final testHarnessModel = HarnessModel(
    id: 'hm-1',
    harness: 'h-1',
    model: 'm-1',
    harnessModelId: 'h-1::m-1',
  );

  final testProviderApiKey = ProviderApiKey(
    id: 'pk-1',
    owner: 'u-1',
    provider: 'anthropic',
    apiKey: '',
  );

  final testProviderCatalogEntry = domain.Provider(
    id: 'p-1',
    providerId: 'anthropic',
    name: 'Anthropic',
    apiKeyEnv: 'ANTHROPIC_API_KEY',
  );

  setUpAll(() {
    registerFallbackValue(_FakeProviderApiKey());
  });

  setUp(() {
    repo = MockProviderRepository();
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('ProviderState', () {
    test('initial() yields idle status with empty lists and no error', () {
      final state = ProviderState.initial();
      expect(state.isIdle, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.isFailure, isFalse);
      expect(state.hasError, isFalse);
      expect(state.harnesses, isEmpty);
      expect(state.models, isEmpty);
      expect(state.harnessModels, isEmpty);
      expect(state.providerAPIKeys, isEmpty);
      expect(state.providerCatalog, isEmpty);
      expect(state.error, isNull);
    });
  });

  group('ProviderCubit.watchAll', () {
    test(
      'subscribe yields loading then loaded with all five collections',
      () async {
        final harnessesCtrl = StreamController<List<Harnesse>>.broadcast();
        final modelsCtrl = StreamController<List<Model>>.broadcast();
        final harnessModelsCtrl =
            StreamController<List<HarnessModel>>.broadcast();
        final harnessProvidersCtrl =
            StreamController<List<HarnessProvider>>.broadcast();
        final providerAPIKeysCtrl =
            StreamController<List<ProviderApiKey>>.broadcast();
        final providerCatalogCtrl =
            StreamController<List<domain.Provider>>.broadcast();
        addTearDown(() async {
          await harnessesCtrl.close();
          await modelsCtrl.close();
          await harnessModelsCtrl.close();
          await harnessProvidersCtrl.close();
          await providerAPIKeysCtrl.close();
          await providerCatalogCtrl.close();
        });

        when(() => repo.watchHarnesses())
            .thenAnswer((_) => harnessesCtrl.stream);
        when(() => repo.watchModels()).thenAnswer((_) => modelsCtrl.stream);
        when(() => repo.watchHarnessModels())
            .thenAnswer((_) => harnessModelsCtrl.stream);
        when(() => repo.watchHarnessProviders())
            .thenAnswer((_) => harnessProvidersCtrl.stream);
        when(() => repo.watchProviderAPIKeys())
            .thenAnswer((_) => providerAPIKeysCtrl.stream);
        when(() => repo.watchProviderCatalog())
            .thenAnswer((_) => providerCatalogCtrl.stream);

        final cubit = buildCubit();
        cubit.watchAll();

        // loading emitted synchronously on the initial emit in watchAll()
        expect(cubit.state.status, UiFlowStatus.loading);

        harnessesCtrl.add([testHarnesse]);
        modelsCtrl.add([testModel]);
        harnessModelsCtrl.add([testHarnessModel]);
        harnessProvidersCtrl.add(const []);
        providerAPIKeysCtrl.add([testProviderApiKey]);
        providerCatalogCtrl.add([testProviderCatalogEntry]);

        // Let the microtasks drain so listen() callbacks fire.
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, UiFlowStatus.success);
        expect(cubit.state.harnesses, [testHarnesse]);
        expect(cubit.state.models, [testModel]);
        expect(cubit.state.harnessModels, [testHarnessModel]);
        expect(cubit.state.providerAPIKeys, [testProviderApiKey]);
        expect(cubit.state.providerCatalog, [testProviderCatalogEntry]);
        expect(cubit.state.isSuccess, isTrue);
        verify(() => repo.watchHarnesses()).called(1);
        verify(() => repo.watchModels()).called(1);
        verify(() => repo.watchHarnessModels()).called(1);
        verify(() => repo.watchHarnessProviders()).called(1);
        verify(() => repo.watchProviderAPIKeys()).called(1);
        verify(() => repo.watchProviderCatalog()).called(1);
      },
    );

    test(
      'harnesses stream error surfaces as failure with the error in state',
      () async {
        final harnessesCtrl = StreamController<List<Harnesse>>.broadcast();
        final modelsCtrl = StreamController<List<Model>>.broadcast();
        final harnessModelsCtrl =
            StreamController<List<HarnessModel>>.broadcast();
        final harnessProvidersCtrl =
            StreamController<List<HarnessProvider>>.broadcast();
        final providerAPIKeysCtrl =
            StreamController<List<ProviderApiKey>>.broadcast();
        final providerCatalogCtrl =
            StreamController<List<domain.Provider>>.broadcast();
        addTearDown(() async {
          await harnessesCtrl.close();
          await modelsCtrl.close();
          await harnessModelsCtrl.close();
          await harnessProvidersCtrl.close();
          await providerAPIKeysCtrl.close();
          await providerCatalogCtrl.close();
        });

        when(() => repo.watchHarnesses())
            .thenAnswer((_) => harnessesCtrl.stream);
        when(() => repo.watchModels()).thenAnswer((_) => modelsCtrl.stream);
        when(() => repo.watchHarnessModels())
            .thenAnswer((_) => harnessModelsCtrl.stream);
        when(() => repo.watchHarnessProviders())
            .thenAnswer((_) => harnessProvidersCtrl.stream);
        when(() => repo.watchProviderAPIKeys())
            .thenAnswer((_) => providerAPIKeysCtrl.stream);
        when(() => repo.watchProviderCatalog())
            .thenAnswer((_) => providerCatalogCtrl.stream);

        final cubit = buildCubit();
        cubit.watchAll();

        harnessesCtrl.addError(Exception('boom'));

        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, UiFlowStatus.failure);
        expect(cubit.state.isFailure, isTrue);
        expect(cubit.state.error, isA<Exception>());
      },
    );
  });

  group('ProviderCubit write methods', () {
    test('saveProviderAPIKey delegates to repo.saveProviderAPIKey', () async {
      when(() => repo.saveProviderAPIKey(any())).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.saveProviderAPIKey(testProviderApiKey);

      verify(() => repo.saveProviderAPIKey(testProviderApiKey)).called(1);
      expect(cubit.state.status, UiFlowStatus.success);
    });

    test('saveProviderAPIKey surfaces repo failure as state error', () async {
      when(() => repo.saveProviderAPIKey(any()))
          .thenThrow(Exception('save failed'));

      final cubit = buildCubit();
      await cubit.saveProviderAPIKey(testProviderApiKey);

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.isFailure, isTrue);
      expect(cubit.state.error, isA<Exception>());
    });

    test('deleteProviderAPIKey delegates to repo.deleteProviderAPIKey',
        () async {
      when(() => repo.deleteProviderAPIKey(any())).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.deleteProviderAPIKey('pk-1');

      verify(() => repo.deleteProviderAPIKey('pk-1')).called(1);
      expect(cubit.state.status, UiFlowStatus.success);
    });

    test('deleteProviderAPIKey surfaces repo failure as state error', () async {
      when(() => repo.deleteProviderAPIKey(any()))
          .thenThrow(Exception('delete failed'));

      final cubit = buildCubit();
      await cubit.deleteProviderAPIKey('pk-1');

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.error, isA<Exception>());
    });
  });
}
