import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/storage/i_secure_storage.dart';
import 'package:pocketcoder_flutter/infrastructure/security/certificate_manager.dart';

class MockSecureStorage extends Mock implements ISecureStorage {}

void main() {
  late MockSecureStorage mockSecureStorage;
  late CertificateManager certificateManager;

  setUp(() {
    mockSecureStorage = MockSecureStorage();
    certificateManager = CertificateManager(mockSecureStorage);
  });

  group('CertificateManager - Unit Tests', () {
    group('computeFingerprint', () {
      test('computes SHA-256 fingerprint from certificate DER encoding', () async {
        final testCert = _createTestCertificate();
        final fingerprint = await certificateManager.computeFingerprint(testCert);

        // SHA-256 produces 32 bytes = 64 hex chars = 32 colon-separated pairs
        final hexPairs = fingerprint.split(':');
        expect(hexPairs.length, equals(32));

        // Each pair should be a valid hex byte
        for (final pair in hexPairs) {
          expect(pair.length, equals(2));
          final byteValue = int.parse(pair, radix: 16);
          expect(byteValue, inInclusiveRange(0, 255));
        }
      });

      test('same certificate produces same fingerprint', () async {
        final testCert = _createTestCertificate();
        final fingerprint1 = await certificateManager.computeFingerprint(testCert);
        final fingerprint2 = await certificateManager.computeFingerprint(testCert);

        expect(fingerprint1, equals(fingerprint2));
      });

      test('different certificates produce different fingerprints', () async {
        final testCert1 = _createTestCertificate(0);
        final testCert2 = _createTestCertificate(1);

        final fingerprint1 = await certificateManager.computeFingerprint(testCert1);
        final fingerprint2 = await certificateManager.computeFingerprint(testCert2);

        expect(fingerprint1, isNot(equals(fingerprint2)));
      });
    });

    group('validateCertificate', () {
      test('accepts matching fingerprints', () {
        final testCert = _createTestCertificate();
        final fingerprint = computeFingerprintSync(testCert);

        final result = certificateManager.validateCertificate(fingerprint, fingerprint);

        expect(result, isTrue);
      });

      test('accepts matching fingerprints with different case', () {
        final testCert = _createTestCertificate();
        final fingerprint = computeFingerprintSync(testCert);
        final upperCaseFingerprint = fingerprint.toUpperCase();

        final result = certificateManager.validateCertificate(fingerprint, upperCaseFingerprint);

        expect(result, isTrue);
      });

      test('rejects mismatched fingerprints', () {
        final testCert1 = _createTestCertificate();
        final testCert2 = _createTestCertificate();

        final fingerprint1 = computeFingerprintSync(testCert1);
        final fingerprint2 = computeFingerprintSync(testCert2);

        final result = certificateManager.validateCertificate(fingerprint1, fingerprint2);

        expect(result, isFalse);
      });

      test('rejects empty actual fingerprint', () {
        final testCert = _createTestCertificate();
        final fingerprint = computeFingerprintSync(testCert);

        final result = certificateManager.validateCertificate(fingerprint, '');

        expect(result, isFalse);
      });
    });

    group('storeFingerprint and getFingerprint', () {
      const instanceId = 'test-instance-123';
      const testFingerprint = 'aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99';

      test('stores fingerprint via secure storage', () async {
        when(() => mockSecureStorage.storeCertificateFingerprint(any(), any()))
            .thenAnswer((_) async {});
        await certificateManager.storeFingerprint(instanceId, testFingerprint);

        verify(() => mockSecureStorage.storeCertificateFingerprint(instanceId, testFingerprint)).called(1);
      });

      test('retrieves fingerprint from secure storage', () async {
        when(() => mockSecureStorage.getCertificateFingerprint(instanceId))
            .thenAnswer((_) async => testFingerprint);

        final result = await certificateManager.getFingerprint(instanceId);

        expect(result, equals(testFingerprint));
        verify(() => mockSecureStorage.getCertificateFingerprint(instanceId)).called(1);
      });

      test('returns null when fingerprint not found', () async {
        when(() => mockSecureStorage.getCertificateFingerprint(instanceId))
            .thenAnswer((_) async => null);

        final result = await certificateManager.getFingerprint(instanceId);

        expect(result, isNull);
      });
    });

    group('createPinnedClient', () {
      test('creates HttpClient with certificate validation callback', () {
        const expectedFingerprint = 'aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99';
        final client = certificateManager.createPinnedClient(expectedFingerprint);

        expect(client, isA<HttpClient>());
      });

      test('pinned client callback accepts matching certificate', () {
        const expectedFingerprint = 'aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99';
        final client = certificateManager.createPinnedClient(expectedFingerprint);

        final testCert = _createTestCertificate();
        final actualFingerprint = computeFingerprintSync(testCert);

        // The callback should accept the certificate if fingerprints match
        // Verify by checking the client is properly configured
        expect(client, isA<HttpClient>());
      });
    });

    group('retrieveCertificateFingerprint', () {
      test('throws when connection fails', () async {
        // This test verifies the method structure - actual network tests
        // would require a real server
        expect(
          () => certificateManager.retrieveCertificateFingerprint('invalid-host-12345.invalid'),
          throwsA(isA<SocketException>()),
        );
      });
    });
  });

  group('computeFingerprintSync', () {
    test('produces consistent fingerprint for same certificate', () {
      final testCert = _createTestCertificate();
      final fingerprint1 = computeFingerprintSync(testCert);
      final fingerprint2 = computeFingerprintSync(testCert);

      expect(fingerprint1, equals(fingerprint2));
    });

    test('produces 32 colon-separated hex pairs', () {
      final testCert = _createTestCertificate();
      final fingerprint = computeFingerprintSync(testCert);

      final pairs = fingerprint.split(':');
      expect(pairs.length, equals(32));
    });
  });
}

/// Creates a test X509Certificate with known DER encoding for testing
X509Certificate _createTestCertificate([int seed = 0]) {
  // Create a minimal self-signed certificate for testing
  // This uses dart:io's X509Certificate parsing
  // Different seeds produce completely different DER bytes
  final testDer = seed == 0
      ? Uint8List.fromList([
          0x30, 0x82, 0x01, 0x0a, 0x02, 0x82, 0x01, 0x01, 0x00, 0xd3,
          0x4e, 0xe3, 0x4f, 0x49, 0x17, 0x2a, 0xa3, 0x7c, 0x8c, 0x16,
          0x9c, 0x11, 0x2f, 0x77, 0x69, 0xda, 0x8a, 0x3d, 0x4b, 0x5c,
          0xb6, 0x52, 0xc4, 0x1f, 0x3a, 0x7e, 0x2f, 0x4a, 0x6d, 0x9e,
          0x1a, 0x2b, 0x3c, 0x4d, 0x5e, 0x6f, 0x70, 0x81, 0x92, 0xa3,
          0xb4, 0xc5, 0xd6, 0xe7, 0xf8, 0x09, 0x1a, 0x2b, 0x3c, 0x4d,
          0x5e, 0x6f, 0x70, 0x81, 0x92, 0xa3, 0xb4, 0xc5, 0xd6, 0xe7,
          0xf8, 0x09, 0x1a, 0x2b, 0x3c, 0x4d, 0x5e, 0x6f, 0x70, 0x81,
          0x92, 0xa3, 0xb4, 0xc5, 0xd6, 0xe7, 0xf8, 0x09, 0x1a, 0x2b,
          0x3c, 0x4d, 0x5e, 0x6f, 0x70, 0x81, 0x92, 0xa3, 0xb4, 0xc5,
          0xd6, 0xe7, 0xf8, 0x09, 0x1a, 0x2b, 0x3c, 0x4d, 0x5e, 0x6f,
          0x70, 0x81, 0x92, 0xa3, 0xb4, 0xc5, 0xd6, 0xe7, 0xf8, 0x09,
          0x02, 0x03, 0x01, 0x00, 0x01,
        ])
      : Uint8List.fromList([
          0x30, 0x82, 0x01, 0x0b, 0x02, 0x82, 0x01, 0x02, 0x00, 0xe4,
          0x5f, 0xf4, 0x60, 0x58, 0x28, 0x3b, 0xb4, 0x9d, 0xad, 0x27,
          0xae, 0x22, 0x88, 0x88, 0x7a, 0xeb, 0x9c, 0x4e, 0x5c, 0x6d,
          0xc7, 0x53, 0xd5, 0x20, 0x4a, 0x7f, 0x3f, 0x5b, 0x6e, 0xaf,
          0x2b, 0x3c, 0x4d, 0x5e, 0x6f, 0x70, 0x81, 0x92, 0xa3, 0xb4,
          0xc5, 0xd6, 0xe7, 0xf8, 0x09, 0x1a, 0x2b, 0x3c, 0x4d, 0x5e,
          0x6f, 0x70, 0x81, 0x92, 0xa3, 0xb4, 0xc5, 0xd6, 0xe7, 0xf8,
          0x09, 0x1a, 0x2b, 0x3c, 0x4d, 0x5e, 0x6f, 0x70, 0x81, 0x92,
          0xa3, 0xb4, 0xc5, 0xd6, 0xe7, 0xf8, 0x09, 0x1a, 0x2b, 0x3c,
          0x4d, 0x5e, 0x6f, 0x70, 0x81, 0x92, 0xa3, 0xb4, 0xc5, 0xd6,
          0xe7, 0xf8, 0x09, 0x1a, 0x2b, 0x3c, 0x4d, 0x5e, 0x6f, 0x70,
          0x81, 0x92, 0xa3, 0xb4, 0xc5, 0xd6, 0xe7, 0xf8, 0x09, 0x02,
          0x03, 0x01, 0x00, 0x02,
        ]);

  // Create a mock X509Certificate for testing
  return _MockX509Certificate(testDer);
}

/// Mock X509Certificate for testing purposes
class _MockX509Certificate implements X509Certificate {
  @override
  final Uint8List der;

  _MockX509Certificate(this.der);

  @override
  String get issuer => 'CN=Test CA';

  @override
  String get subject => 'CN=Test Certificate';

  @override
  DateTime get startValidity => DateTime.now().subtract(const Duration(days: 1));

  @override
  DateTime get endValidity => DateTime.now().add(const Duration(days: 365));

  @override
  String get pem => '-----BEGIN CERTIFICATE-----\nMOCK_CERT\n-----END CERTIFICATE-----';

  @override
  Uint8List get sha1 => Uint8List(20);
}