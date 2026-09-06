import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/exceptions/model_search_exception.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/infrastructure/model_search/model_search_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/provider/provider_daos.dart';

class MockHarnesseDao extends Mock implements HarnesseDao {}

class MockHarnessModelDao extends Mock implements HarnessModelDao {}

class MockModelDao extends Mock implements ModelDao {}

class MockProviderCatalogDao extends Mock implements ProviderCatalogDao {}

class MockProviderAPIKeyDao extends Mock implements ProviderAPIKeyDao {}

void main() {
  late ModelSearchRepository repo;
  late MockHarnesseDao harnesseDao;
  late MockHarnessModelDao harnessModelDao;
  late MockModelDao modelDao;
  late MockProviderCatalogDao providerCatalogDao;
  late MockProviderAPIKeyDao providerAPIKeyDao;

  const harness = Harnesse(
    id: 'harness-1',
    name: 'OpenCode',
    cliId: 'opencode',
    acpTransport: HarnesseAcpTransport.stdio,
    providerFanout: true,
  );

  setUp(() {
    harnesseDao = MockHarnesseDao();
    harnessModelDao = MockHarnessModelDao();
    modelDao = MockModelDao();
    providerCatalogDao = MockProviderCatalogDao();
    providerAPIKeyDao = MockProviderAPIKeyDao();
    when(() => harnessModelDao.pb).thenReturn(PocketBase('http://localhost'));
    repo = ModelSearchRepository(
        harnesseDao, harnessModelDao, modelDao, providerCatalogDao, providerAPIKeyDao);
  });

  group('harnessFor', () {
    test('returns the harness record', () async {
      when(() => harnesseDao.getOne('harness-1')).thenAnswer((_) async => harness);

      final result = await repo.harnessFor('harness-1');

      expect(result, harness);
    });

    test('wraps a DAO failure as ModelSearchException', () async {
      when(() => harnesseDao.getOne('harness-1'))
          .thenThrow(Exception('network down'));

      await expectLater(
        repo.harnessFor('harness-1'),
        throwsA(isA<ModelSearchException>()),
      );
    });
  });

  group('modelsFor', () {
    test('returns every catalog row for the harness when no provider given',
        () async {
      final rows = [
        const HarnessModel(
            id: 'hm-1', harness: 'harness-1', model: 'm-1', harnessModelId: 'a'),
        const HarnessModel(
            id: 'hm-2', harness: 'harness-1', model: 'm-2', harnessModelId: 'b'),
      ];
      when(() => harnessModelDao.getFullList(filter: 'harness = "harness-1"'))
          .thenAnswer((_) async => rows);

      final result = await repo.modelsFor('harness-1');

      expect(result, rows);
      verifyNever(() => modelDao.getFullList());
    });

    test('narrows to rows whose model belongs to the given provider',
        () async {
      final rows = [
        const HarnessModel(
            id: 'hm-openrouter',
            harness: 'harness-1',
            model: 'm-openrouter',
            harnessModelId: 'anthropic/claude-sonnet-4.5'),
        const HarnessModel(
            id: 'hm-orca',
            harness: 'harness-1',
            model: 'm-orca',
            harnessModelId: 'anthropic/claude-sonnet-4.5'),
      ];
      when(() => harnessModelDao.getFullList(filter: 'harness = "harness-1"'))
          .thenAnswer((_) async => rows);
      when(() => modelDao.getFullList()).thenAnswer((_) async => const [
            Model(id: 'm-openrouter', name: 'Sonnet 4.5', provider: 'prov-openrouter'),
            Model(id: 'm-orca', name: 'Sonnet 4.5', provider: 'prov-orca'),
          ]);

      final result = await repo.modelsFor('harness-1', providerId: 'prov-openrouter');

      expect(result, [rows[0]]);
    });

    test('wraps a DAO failure as ModelSearchException', () async {
      when(() => harnessModelDao.getFullList(filter: 'harness = "harness-1"'))
          .thenThrow(Exception('boom'));

      await expectLater(
        repo.modelsFor('harness-1'),
        throwsA(isA<ModelSearchException>()),
      );
    });
  });

  group('credentialedProvidersFor', () {
    test(
        'returns only providers that both have synced models for this '
        'harness and a stored API key', () async {
      when(() => harnessModelDao.getFullList(filter: 'harness = "harness-1"'))
          .thenAnswer((_) async => const [
                HarnessModel(
                    id: 'hm-openrouter',
                    harness: 'harness-1',
                    model: 'm-openrouter',
                    harnessModelId: 'anthropic/claude-sonnet-4.5'),
                HarnessModel(
                    id: 'hm-orca',
                    harness: 'harness-1',
                    model: 'm-orca',
                    harnessModelId: 'anthropic/claude-sonnet-4.5'),
                HarnessModel(
                    id: 'hm-uncredentialed-elsewhere',
                    harness: 'harness-1',
                    model: 'm-anthropic-direct',
                    harnessModelId: 'claude-sonnet-4-5'),
              ]);
      when(() => modelDao.getFullList()).thenAnswer((_) async => const [
            Model(id: 'm-openrouter', name: 'Sonnet 4.5', provider: 'prov-openrouter'),
            Model(id: 'm-orca', name: 'Sonnet 4.5', provider: 'prov-orca'),
            Model(id: 'm-anthropic-direct', name: 'Sonnet 4.5', provider: 'prov-anthropic'),
          ]);
      when(() => providerAPIKeyDao.getFullList()).thenAnswer((_) async => const [
            ProviderApiKey(
                id: 'key-1', owner: 'user-1', provider: 'prov-openrouter', apiKey: 'sk-x'),
          ]);
      when(() => providerCatalogDao.getFullList()).thenAnswer((_) async => const [
            domain.Provider(id: 'prov-openrouter', providerId: 'openrouter', name: 'OpenRouter'),
            domain.Provider(id: 'prov-orca', providerId: 'orcarouter', name: 'OrcaRouter'),
            domain.Provider(id: 'prov-anthropic', providerId: 'anthropic', name: 'Anthropic'),
          ]);

      final result = await repo.credentialedProvidersFor('harness-1');

      expect(result.map((p) => p.id), ['prov-openrouter']);
    });

    test('returns nothing without hitting other DAOs when the harness has '
        'no synced models', () async {
      when(() => harnessModelDao.getFullList(filter: 'harness = "harness-1"'))
          .thenAnswer((_) async => const []);

      final result = await repo.credentialedProvidersFor('harness-1');

      expect(result, isEmpty);
      verifyNever(() => modelDao.getFullList());
      verifyNever(() => providerAPIKeyDao.getFullList());
      verifyNever(() => providerCatalogDao.getFullList());
    });

    test('returns nothing without querying the provider catalog when no '
        'synced model has a credentialed provider', () async {
      when(() => harnessModelDao.getFullList(filter: 'harness = "harness-1"'))
          .thenAnswer((_) async => const [
                HarnessModel(
                    id: 'hm-orca',
                    harness: 'harness-1',
                    model: 'm-orca',
                    harnessModelId: 'anthropic/claude-sonnet-4.5'),
              ]);
      when(() => modelDao.getFullList()).thenAnswer((_) async => const [
            Model(id: 'm-orca', name: 'Sonnet 4.5', provider: 'prov-orca'),
          ]);
      when(() => providerAPIKeyDao.getFullList()).thenAnswer((_) async => const []);

      final result = await repo.credentialedProvidersFor('harness-1');

      expect(result, isEmpty);
      verifyNever(() => providerCatalogDao.getFullList());
    });

    test('wraps a DAO failure as ModelSearchException', () async {
      when(() => harnessModelDao.getFullList(filter: 'harness = "harness-1"'))
          .thenThrow(Exception('boom'));

      await expectLater(
        repo.credentialedProvidersFor('harness-1'),
        throwsA(isA<ModelSearchException>()),
      );
    });
  });

  group('modelsAvailableFor', () {
    const nonFanoutHarness = Harnesse(
      id: 'harness-1',
      name: 'Claude Code',
      cliId: 'claude-code',
      acpTransport: HarnesseAcpTransport.stdio,
      providerFanout: false,
    );
    const fanoutHarness = Harnesse(
      id: 'harness-1',
      name: 'OpenCode',
      cliId: 'opencode',
      acpTransport: HarnesseAcpTransport.stdio,
      providerFanout: true,
    );

    test('returns every catalog row unfiltered for a non-fanout harness',
        () async {
      final rows = [
        const HarnessModel(
            id: 'hm-1', harness: 'harness-1', model: 'm-1', harnessModelId: 'a'),
        const HarnessModel(
            id: 'hm-2', harness: 'harness-1', model: 'm-2', harnessModelId: 'b'),
      ];
      when(() => harnesseDao.getOne('harness-1'))
          .thenAnswer((_) async => nonFanoutHarness);
      when(() => harnessModelDao.getFullList(filter: 'harness = "harness-1"'))
          .thenAnswer((_) async => rows);

      final result = await repo.modelsAvailableFor('harness-1');

      expect(result, rows);
      verifyNever(() => modelDao.getFullList());
      verifyNever(() => providerAPIKeyDao.getFullList());
    });

    test(
        'returns only the rows whose provider is credentialed for a fanout '
        'harness', () async {
      when(() => harnesseDao.getOne('harness-1'))
          .thenAnswer((_) async => fanoutHarness);
      when(() => harnessModelDao.getFullList(filter: 'harness = "harness-1"'))
          .thenAnswer((_) async => const [
                HarnessModel(
                    id: 'hm-openrouter',
                    harness: 'harness-1',
                    model: 'm-openrouter',
                    harnessModelId: 'anthropic/claude-sonnet-4.5'),
                HarnessModel(
                    id: 'hm-orca',
                    harness: 'harness-1',
                    model: 'm-orca',
                    harnessModelId: 'anthropic/claude-sonnet-4.5'),
              ]);
      when(() => modelDao.getFullList()).thenAnswer((_) async => const [
            Model(id: 'm-openrouter', name: 'Sonnet 4.5', provider: 'prov-openrouter'),
            Model(id: 'm-orca', name: 'Sonnet 4.5', provider: 'prov-orca'),
          ]);
      when(() => providerAPIKeyDao.getFullList()).thenAnswer((_) async => const [
            ProviderApiKey(
                id: 'key-1', owner: 'user-1', provider: 'prov-openrouter', apiKey: 'sk-x'),
          ]);

      final result = await repo.modelsAvailableFor('harness-1');

      expect(result.map((hm) => hm.id), ['hm-openrouter']);
      verifyNever(() => providerCatalogDao.getFullList());
    });

    test(
        'returns nothing without hitting the model/key DAOs when a fanout '
        'harness has no synced models', () async {
      when(() => harnesseDao.getOne('harness-1'))
          .thenAnswer((_) async => fanoutHarness);
      when(() => harnessModelDao.getFullList(filter: 'harness = "harness-1"'))
          .thenAnswer((_) async => const []);

      final result = await repo.modelsAvailableFor('harness-1');

      expect(result, isEmpty);
      verifyNever(() => modelDao.getFullList());
      verifyNever(() => providerAPIKeyDao.getFullList());
    });

    test('wraps a DAO failure as ModelSearchException', () async {
      when(() => harnesseDao.getOne('harness-1')).thenThrow(Exception('boom'));

      await expectLater(
        repo.modelsAvailableFor('harness-1'),
        throwsA(isA<ModelSearchException>()),
      );
    });
  });
}
