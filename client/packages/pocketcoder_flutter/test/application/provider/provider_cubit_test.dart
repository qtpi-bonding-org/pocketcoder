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
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';

class MockProviderRepository extends Mock implements IProviderRepository {}

class _FakeProviderKey extends Fake implements ProviderKey {}

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

  final testProviderKey = ProviderKey(
    id: 'pk-1',
    user: 'u-1',
    provider: 'anthropic',
  );

  final testProviderCatalogEntry = domain.Provider(
    id: 'p-1',
    providerId: 'anthropic',
    name: 'Anthropic',
    apiKeyEnv: 'ANTHROPIC_API_KEY',
  );

  setUpAll(() {
    registerFallbackValue(_FakeProviderKey());
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
      expect(state.providerKeys, isEmpty);
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
        final providerKeysCtrl =
            StreamController<List<ProviderKey>>.broadcast();
        final providerCatalogCtrl =
            StreamController<List<domain.Provider>>.broadcast();
        addTearDown(() async {
          await harnessesCtrl.close();
          await modelsCtrl.close();
          await harnessModelsCtrl.close();
          await providerKeysCtrl.close();
          await providerCatalogCtrl.close();
        });

        when(() => repo.watchHarnesses())
            .thenAnswer((_) => harnessesCtrl.stream);
        when(() => repo.watchModels()).thenAnswer((_) => modelsCtrl.stream);
        when(() => repo.watchHarnessModels())
            .thenAnswer((_) => harnessModelsCtrl.stream);
        when(() => repo.watchProviderKeys())
            .thenAnswer((_) => providerKeysCtrl.stream);
        when(() => repo.watchProviderCatalog())
            .thenAnswer((_) => providerCatalogCtrl.stream);

        final cubit = buildCubit();
        cubit.watchAll();

        // loading emitted synchronously on the initial emit in watchAll()
        expect(cubit.state.status, UiFlowStatus.loading);

        harnessesCtrl.add([testHarnesse]);
        modelsCtrl.add([testModel]);
        harnessModelsCtrl.add([testHarnessModel]);
        providerKeysCtrl.add([testProviderKey]);
        providerCatalogCtrl.add([testProviderCatalogEntry]);

        // Let the microtasks drain so listen() callbacks fire.
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, UiFlowStatus.success);
        expect(cubit.state.harnesses, [testHarnesse]);
        expect(cubit.state.models, [testModel]);
        expect(cubit.state.harnessModels, [testHarnessModel]);
        expect(cubit.state.providerKeys, [testProviderKey]);
        expect(cubit.state.providerCatalog, [testProviderCatalogEntry]);
        expect(cubit.state.isSuccess, isTrue);
        verify(() => repo.watchHarnesses()).called(1);
        verify(() => repo.watchModels()).called(1);
        verify(() => repo.watchHarnessModels()).called(1);
        verify(() => repo.watchProviderKeys()).called(1);
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
        final providerKeysCtrl =
            StreamController<List<ProviderKey>>.broadcast();
        final providerCatalogCtrl =
            StreamController<List<domain.Provider>>.broadcast();
        addTearDown(() async {
          await harnessesCtrl.close();
          await modelsCtrl.close();
          await harnessModelsCtrl.close();
          await providerKeysCtrl.close();
          await providerCatalogCtrl.close();
        });

        when(() => repo.watchHarnesses())
            .thenAnswer((_) => harnessesCtrl.stream);
        when(() => repo.watchModels()).thenAnswer((_) => modelsCtrl.stream);
        when(() => repo.watchHarnessModels())
            .thenAnswer((_) => harnessModelsCtrl.stream);
        when(() => repo.watchProviderKeys())
            .thenAnswer((_) => providerKeysCtrl.stream);
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
    test('saveProviderKey delegates to repo.saveProviderKey', () async {
      when(() => repo.saveProviderKey(any())).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.saveProviderKey(testProviderKey);

      verify(() => repo.saveProviderKey(testProviderKey)).called(1);
      expect(cubit.state.status, UiFlowStatus.success);
    });

    test('saveProviderKey surfaces repo failure as state error', () async {
      when(() => repo.saveProviderKey(any()))
          .thenThrow(Exception('save failed'));

      final cubit = buildCubit();
      await cubit.saveProviderKey(testProviderKey);

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.isFailure, isTrue);
      expect(cubit.state.error, isA<Exception>());
    });

    test('deleteProviderKey delegates to repo.deleteProviderKey', () async {
      when(() => repo.deleteProviderKey(any())).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.deleteProviderKey('pk-1');

      verify(() => repo.deleteProviderKey('pk-1')).called(1);
      expect(cubit.state.status, UiFlowStatus.success);
    });

    test('deleteProviderKey surfaces repo failure as state error', () async {
      when(() => repo.deleteProviderKey(any()))
          .thenThrow(Exception('delete failed'));

      final cubit = buildCubit();
      await cubit.deleteProviderKey('pk-1');

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.error, isA<Exception>());
    });
  });
}
