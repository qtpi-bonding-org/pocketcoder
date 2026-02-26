import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/models/instance_credentials.dart';
import 'package:pocketcoder_flutter/infrastructure/storage/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorage', () {
    late SecureStorage secureStorage;
    late FlutterSecureStorage mockStorage;

    setUp(() {
      mockStorage = const FlutterSecureStorage();
      secureStorage = SecureStorage(storage: mockStorage);
    });

    tearDown(() async {
      await secureStorage.clearAll();
    });

    group('Token Storage', () {
      test('storeAccessToken and getAccessToken round-trip', () async {
        const testToken = 'test_access_token_12345';
        await secureStorage.storeAccessToken(testToken);
        final retrieved = await secureStorage.getAccessToken();
        expect(retrieved, equals(testToken));
      });

      test('storeRefreshToken and getRefreshToken round-trip', () async {
        const testToken = 'test_refresh_token_67890';
        await secureStorage.storeRefreshToken(testToken);
        final retrieved = await secureStorage.getRefreshToken();
        expect(retrieved, equals(testToken));
      });

      test('storeTokenExpiration and getTokenExpiration round-trip', () async {
        final testDate = DateTime(2025, 6, 15, 10, 30, 0);
        await secureStorage.storeTokenExpiration(testDate);
        final retrieved = await secureStorage.getTokenExpiration();
        expect(retrieved, equals(testDate));
      });

      test('storeCodeVerifier and getCodeVerifier round-trip', () async {
        const testVerifier = 'test_code_verifier_pkce';
        await secureStorage.storeCodeVerifier(testVerifier);
        final retrieved = await secureStorage.getCodeVerifier();
        expect(retrieved, equals(testVerifier));
      });
    });

    group('Instance Credentials Storage', () {
      test('storeInstanceCredentials and getInstanceCredentials round-trip', () async {
        final credentials = InstanceCredentials(
          instanceId: 'test-instance-123',
          adminEmail: 'admin@test.com',
          adminPassword: 'AdminPass123!',
          rootPassword: 'RootPass456@',
        );
        await secureStorage.storeInstanceCredentials(credentials);
        final retrieved = await secureStorage.getInstanceCredentials('test-instance-123');
        expect(retrieved, equals(credentials));
      });

      test('getInstanceCredentials returns null for non-existent instance', () async {
        final retrieved = await secureStorage.getInstanceCredentials('non-existent-id');
        expect(retrieved, isNull);
      });
    });

    group('Certificate Fingerprint Storage', () {
      test('storeCertificateFingerprint and getCertificateFingerprint round-trip', () async {
        const testFingerprint = 'sha256:abc123def456';
        await secureStorage.storeCertificateFingerprint('instance-456', testFingerprint);
        final retrieved = await secureStorage.getCertificateFingerprint('instance-456');
        expect(retrieved, equals(testFingerprint));
      });

      test('getCertificateFingerprint returns null for non-existent instance', () async {
        final retrieved = await secureStorage.getCertificateFingerprint('non-existent-id');
        expect(retrieved, isNull);
      });
    });

    group('clearAll', () {
      test('clearAll removes all stored data', () async {
        await secureStorage.storeAccessToken('test_token');
        await secureStorage.storeRefreshToken('test_refresh');
        await secureStorage.storeCodeVerifier('test_verifier');

        await secureStorage.clearAll();

        expect(await secureStorage.getAccessToken(), isNull);
        expect(await secureStorage.getRefreshToken(), isNull);
        expect(await secureStorage.getCodeVerifier(), isNull);
      });
    });
  });
}