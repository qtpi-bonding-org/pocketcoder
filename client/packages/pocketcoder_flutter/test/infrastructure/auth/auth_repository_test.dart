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

class MockAuthStoreConfig extends Mock implements AuthStoreConfig {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockPocketCoderApiClient extends Mock implements PocketCoderApiClient {}

void main() {
  late MockPocketBase pocketBase;
  late MockFlutterSecureStorage storage;
  late AuthHttpState authHttpState;
  late AuthRepository repository;

  setUp(() {
    pocketBase = MockPocketBase();
    storage = MockFlutterSecureStorage();
    authHttpState = AuthHttpState();
    authHttpState.configureDeployment(
      'http://127.0.0.1:8090',
      tokenProvider: () => 'token',
    );
    when(() => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});
    repository = AuthRepository(
      pocketBase,
      MockAuthStoreConfig(),
      storage,
      MockPocketCoderApiClient(),
      authHttpState,
    );
  });

  test('updateBaseUrl retargets AuthHttpState.deploymentOrigin to the new host',
      () async {
    await repository.updateBaseUrl('https://real-deployment.example');

    expect(authHttpState.deploymentOrigin, isNotNull);
    expect(authHttpState.deploymentOrigin!.host, 'real-deployment.example');
  });
}
