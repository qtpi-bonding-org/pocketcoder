import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/exceptions/provider_exception.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/provider/provider_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/provider/provider_repository.dart';

class MockHarnesseDao extends Mock implements HarnesseDao {}

class MockModelDao extends Mock implements ModelDao {}

class MockHarnessModelDao extends Mock implements HarnessModelDao {}

class MockProviderAPIKeyDao extends Mock implements ProviderAPIKeyDao {}

class MockHarnessProviderDao extends Mock implements HarnessProviderDao {}

class MockProviderCatalogDao extends Mock implements ProviderCatalogDao {}

class MockAuthRepository extends Mock implements IAuthRepository {}

class _FakeProviderApiKey extends Fake implements ProviderApiKey {}

void main() {
  late ProviderRepository repo;
  late MockHarnesseDao harnesseDao;
  late MockModelDao modelDao;
  late MockHarnessModelDao harnessModelDao;
  late MockProviderAPIKeyDao providerAPIKeyDao;
  late MockHarnessProviderDao harnessProviderDao;
  late MockProviderCatalogDao providerCatalogDao;
  late MockAuthRepository authRepository;

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

  final testProviderAPIKey = ProviderApiKey(
    id: 'pk-1',
    owner: 'user-1',
    provider: 'anthropic',
    apiKey: 'sk-test',
  );

  final testHarnessProvider = HarnessProvider(
    id: 'hp-1',
    harness: 'h-1',
    provider: 'p-1',
    supportsOauth: true,
  );

  final testProviderCatalogEntry = domain.Provider(
    id: 'p-1',
    providerId: 'anthropic',
    name: 'Anthropic',
    apiKeyEnv: 'ANTHROPIC_API_KEY',
  );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(_FakeProviderApiKey());
  });

  setUp(() {
    harnesseDao = MockHarnesseDao();
    modelDao = MockModelDao();
    harnessModelDao = MockHarnessModelDao();
    providerAPIKeyDao = MockProviderAPIKeyDao();
    harnessProviderDao = MockHarnessProviderDao();
    providerCatalogDao = MockProviderCatalogDao();
    authRepository = MockAuthRepository();
    when(() => authRepository.currentUserId).thenReturn('user-1');
    repo = ProviderRepository(
      harnesseDao,
      modelDao,
      harnessModelDao,
      providerAPIKeyDao,
      harnessProviderDao,
      providerCatalogDao,
      authRepository,
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

  test('watchProviderAPIKeys forwards providerAPIKeyDao.watch()', () {
    final stream = Stream<List<ProviderApiKey>>.value([testProviderAPIKey]);
    when(() => providerAPIKeyDao.watch()).thenAnswer((_) => stream);

    expect(repo.watchProviderAPIKeys(), emits([testProviderAPIKey]));
    verify(() => providerAPIKeyDao.watch()).called(1);
  });

  test('watchHarnessProviders forwards harnessProviderDao.watch()', () {
    final stream = Stream<List<HarnessProvider>>.value([testHarnessProvider]);
    when(() => harnessProviderDao.watch()).thenAnswer((_) => stream);

    expect(repo.watchHarnessProviders(), emits([testHarnessProvider]));
    verify(() => harnessProviderDao.watch()).called(1);
  });

  test('watchProviderCatalog forwards providerCatalogDao.watch()', () {
    final stream =
        Stream<List<domain.Provider>>.value([testProviderCatalogEntry]);
    when(() => providerCatalogDao.watch()).thenAnswer((_) => stream);

    expect(repo.watchProviderCatalog(), emits([testProviderCatalogEntry]));
    verify(() => providerCatalogDao.watch()).called(1);
  });

  test(
      'saveProviderAPIKey calls providerAPIKeyDao.save with id and toJson, '
      'wraps failures in ProviderException', () async {
    when(() => providerAPIKeyDao.save(any(), any()))
        .thenAnswer((_) async => testProviderAPIKey);

    await repo.saveProviderAPIKey(testProviderAPIKey);
    verify(() => providerAPIKeyDao.save(
          testProviderAPIKey.id,
          testProviderAPIKey.toJson(),
        )).called(1);

    when(() => providerAPIKeyDao.save(any(), any()))
        .thenThrow(Exception('boom'));
    await expectLater(
      () => repo.saveProviderAPIKey(testProviderAPIKey),
      throwsA(isA<ProviderException>()),
    );
  });

  // Regression test: a brand-new key always arrives with owner: '' (the
  // onboarding dialog only ever copies an *existing* record's owner --
  // there is none for a new key). provider_api_keys.createRule requires
  // owner = @request.auth.id, and PocketBase evaluates that rule against
  // the client-submitted data itself, before any server-side hook could
  // fix it up -- so an unfilled owner made every real create fail outright
  // ("Failed to create record"), breaking the entire API-key onboarding
  // path end to end until this was caught and fixed here.
  test(
      'saveProviderAPIKey fills owner from the authenticated user for a '
      'brand-new key', () async {
    final newKey = ProviderApiKey(
      id: '',
      owner: '',
      provider: 'anthropic',
      apiKey: 'sk-new',
    );
    when(() => providerAPIKeyDao.save(any(), any()))
        .thenAnswer((_) async => newKey);

    await repo.saveProviderAPIKey(newKey);

    final captured = verify(() => providerAPIKeyDao.save('', captureAny()))
        .captured
        .single as Map<String, dynamic>;
    expect(captured['owner'], 'user-1');
  });

  test(
      'deleteProviderAPIKey calls providerAPIKeyDao.delete and '
      'wraps failures in ProviderException', () async {
    when(() => providerAPIKeyDao.delete(any())).thenAnswer((_) async {});

    await repo.deleteProviderAPIKey('pk-1');
    verify(() => providerAPIKeyDao.delete('pk-1')).called(1);

    when(() => providerAPIKeyDao.delete(any())).thenThrow(Exception('boom'));
    await expectLater(
      () => repo.deleteProviderAPIKey('pk-1'),
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
