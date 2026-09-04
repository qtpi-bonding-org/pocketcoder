// Regression tests for two related audit findings:
// - Bug A: updateBaseUrl used to persist the candidate URL to secure
//   storage immediately, before it was ever verified -- one typo on the
//   login screen could permanently overwrite the last-known-good URL.
// - Bug B: nothing ever retargeted AuthHttpState.deploymentOrigin after
//   the first (DI-time, local-default) configuration, so 401 recovery
//   never engaged for the real deployment host once one was set.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/infrastructure/auth/auth_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/auth_aware_http_client.dart';
import 'package:pocketcoder_flutter/infrastructure/core/auth_store.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';

class MockPocketBase extends Mock implements PocketBase {}

class MockDollarPocketBase extends Mock implements $PocketBase {}

class MockDataBase extends Mock implements DataBase {}

class MockAuthStore extends Mock implements AuthStore {}

class MockAuthStoreConfig extends Mock implements AuthStoreConfig {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockPocketCoderApiClient extends Mock implements PocketCoderApiClient {}

void main() {
  late MockPocketBase pocketBase;
  late MockAuthStore authStore;
  late MockFlutterSecureStorage storage;
  late MockAuthStoreConfig authStoreConfig;
  late AuthHttpState authHttpState;
  late AuthRepository repository;

  setUp(() {
    pocketBase = MockPocketBase();
    authStore = MockAuthStore();
    storage = MockFlutterSecureStorage();
    authStoreConfig = MockAuthStoreConfig();
    authHttpState = AuthHttpState();
    authHttpState.configureDeployment(
      'http://127.0.0.1:8090',
      tokenProvider: () => 'token',
    );
    when(() => pocketBase.authStore).thenReturn(authStore);
    when(() => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});
    repository = AuthRepository(
      pocketBase,
      authStoreConfig,
      storage,
      MockPocketCoderApiClient(),
      authHttpState,
    );
  });

  test('clearSession clears auth state and the persisted server URL', () async {
    when(() => authStore.clear()).thenReturn(null);
    when(() => authStoreConfig.clear()).thenAnswer((_) async {});
    when(() => storage.delete(key: 'pb_server_url')).thenAnswer((_) async {});

    await repository.clearSession();

    verify(() => authStore.clear()).called(1);
    verify(() => authStoreConfig.clear()).called(1);
    verify(() => storage.delete(key: 'pb_server_url')).called(1);
  });

  test(
      'clearSession also wipes pocketbase_drift\'s local offline cache -- '
      'otherwise a previously-synced chat list stays readable straight off '
      'disk with no auth and no network at all', () async {
    final dollarPocketBase = MockDollarPocketBase();
    final db = MockDataBase();
    when(() => dollarPocketBase.authStore).thenReturn(authStore);
    when(() => dollarPocketBase.db).thenReturn(db);
    when(() => db.clearAllData()).thenAnswer((_) async {});
    when(() => authStoreConfig.clear()).thenAnswer((_) async {});
    when(() => storage.delete(key: 'pb_server_url')).thenAnswer((_) async {});
    final repositoryWithDrift = AuthRepository(
      dollarPocketBase,
      authStoreConfig,
      storage,
      MockPocketCoderApiClient(),
      authHttpState,
    );

    await repositoryWithDrift.clearSession();

    verify(() => db.clearAllData()).called(1);
  });

  test('updateBaseUrl retargets AuthHttpState.deploymentOrigin to the new host',
      () async {
    await repository.updateBaseUrl('https://real-deployment.example');

    expect(authHttpState.deploymentOrigin, isNotNull);
    expect(authHttpState.deploymentOrigin?.host, 'real-deployment.example');
  });
}
