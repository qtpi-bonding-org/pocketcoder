import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/exceptions/provider_exception.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/provider/provider_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/provider/provider_repository.dart';

class MockHarnesseDao extends Mock implements HarnesseDao {}

class MockModelDao extends Mock implements ModelDao {}

class MockHarnessModelDao extends Mock implements HarnessModelDao {}

class MockProviderKeyDao extends Mock implements ProviderKeyDao {}

class MockProviderCatalogDao extends Mock implements ProviderCatalogDao {}

class _FakeProviderKey extends Fake implements ProviderKey {}

void main() {
  late ProviderRepository repo;
  late MockHarnesseDao harnesseDao;
  late MockModelDao modelDao;
  late MockHarnessModelDao harnessModelDao;
  late MockProviderKeyDao providerKeyDao;
  late MockProviderCatalogDao providerCatalogDao;

  final testHarnesse = Harnesse(
    id: 'h-1',
    name: 'claude-code',
    cliId: 'claude',
    acpTransport: HarnesseAcpTransport.websocket,
  );

  final testModel = Model(
    id: 'm-1',
    name: 'claude-opus',
    provider: 'anthropic',
  );

  final testHarnessModel = HarnessModel(
    id: 'hm-1',
    harness: 'h-1',
    model: 'm-1',
    harnessModelId: 'claude-opus-via-claude-code',
  );

  final testProviderKey = ProviderKey(
    id: 'pk-1',
    user: 'user-1',
    provider: 'anthropic',
    envVars: {'ANTHROPIC_API_KEY': 'sk-test'},
  );

  final testProviderCatalogEntry = domain.Provider(
    id: 'p-1',
    providerId: 'anthropic',
    name: 'Anthropic',
    apiKeyEnv: 'ANTHROPIC_API_KEY',
  );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(_FakeProviderKey());
  });

  setUp(() {
    harnesseDao = MockHarnesseDao();
    modelDao = MockModelDao();
    harnessModelDao = MockHarnessModelDao();
    providerKeyDao = MockProviderKeyDao();
    providerCatalogDao = MockProviderCatalogDao();
    repo = ProviderRepository(
      harnesseDao,
      modelDao,
      harnessModelDao,
      providerKeyDao,
      providerCatalogDao,
    );
  });

  test('watchHarnesses forwards harnesseDao.watch()', () {
    final stream = Stream<List<Harnesse>>.value([testHarnesse]);
    when(() => harnesseDao.watch()).thenAnswer((_) => stream);

    expect(repo.watchHarnesses(), emits([testHarnesse]));
    verify(() => harnesseDao.watch()).called(1);
  });

  test('watchModels forwards modelDao.watch()', () {
    final stream = Stream<List<Model>>.value([testModel]);
    when(() => modelDao.watch()).thenAnswer((_) => stream);

    expect(repo.watchModels(), emits([testModel]));
    verify(() => modelDao.watch()).called(1);
  });

  test('watchHarnessModels forwards harnessModelDao.watch()', () {
    final stream = Stream<List<HarnessModel>>.value([testHarnessModel]);
    when(() => harnessModelDao.watch()).thenAnswer((_) => stream);

    expect(repo.watchHarnessModels(), emits([testHarnessModel]));
    verify(() => harnessModelDao.watch()).called(1);
  });

  test('watchProviderKeys forwards providerKeyDao.watch()', () {
    final stream = Stream<List<ProviderKey>>.value([testProviderKey]);
    when(() => providerKeyDao.watch()).thenAnswer((_) => stream);

    expect(repo.watchProviderKeys(), emits([testProviderKey]));
    verify(() => providerKeyDao.watch()).called(1);
  });

  test('watchProviderCatalog forwards providerCatalogDao.watch()', () {
    final stream =
        Stream<List<domain.Provider>>.value([testProviderCatalogEntry]);
    when(() => providerCatalogDao.watch()).thenAnswer((_) => stream);

    expect(repo.watchProviderCatalog(), emits([testProviderCatalogEntry]));
    verify(() => providerCatalogDao.watch()).called(1);
  });

  test(
      'saveProviderKey calls providerKeyDao.save with id and toJson, '
      'wraps failures in ProviderException', () async {
    when(() => providerKeyDao.save(any(), any()))
        .thenAnswer((_) async => testProviderKey);

    await repo.saveProviderKey(testProviderKey);
    verify(() => providerKeyDao.save(
          testProviderKey.id,
          testProviderKey.toJson(),
        )).called(1);

    when(() => providerKeyDao.save(any(), any()))
        .thenThrow(Exception('boom'));
    await expectLater(
      () => repo.saveProviderKey(testProviderKey),
      throwsA(isA<ProviderException>()),
    );
  });

  test(
      'deleteProviderKey calls providerKeyDao.delete and '
      'wraps failures in ProviderException', () async {
    when(() => providerKeyDao.delete(any())).thenAnswer((_) async {});

    await repo.deleteProviderKey('pk-1');
    verify(() => providerKeyDao.delete('pk-1')).called(1);

    when(() => providerKeyDao.delete(any())).thenThrow(Exception('boom'));
    await expectLater(
      () => repo.deleteProviderKey('pk-1'),
      throwsA(isA<ProviderException>()),
    );
  });

  test('exposes IProviderRepository methods via interface', () {
    // Compile-time-assertion-shaped smoke test: ProviderRepository must
    // satisfy IProviderRepository so it can be registered via
    // @LazySingleton(as: IProviderRepository).
    expect(repo, isA<IProviderRepository>());
  });
}
