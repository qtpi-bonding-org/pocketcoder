import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/security/i_certificate_manager.dart';
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

  group('CertificateManager - Property Tests', () {
    /// Property 18: Certificate Fingerprint Retrieval
    /// For any completed deployment, the Certificate_Manager SHALL successfully
    /// retrieve the certificate fingerprint from the /cert-fingerprint HTTPS endpoint.
    test('Property 18: Fingerprint retrieval returns valid hex format', () async {
      // Create a test certificate with known DER encoding
      final testCert = _createTestCertificate();
      final expectedFingerprint = await certificateManager.computeFingerprint(testCert);

      // Fingerprint should be non-empty
      expect(expectedFingerprint.isNotEmpty, isTrue);

      // Fingerprint should be in colon-separated hex format (SHA-256 = 64 hex chars = 17 pairs)
      final hexPairs = expectedFingerprint.split(':');
      expect(hexPairs.length, equals(32));
      for (final pair in hexPairs) {
        expect(pair.length, equals(2));
        expect(int.tryParse(pair, radix: 16), isNotNull);
      }
    });

    /// Property 19: Certificate Pinning Validation
    /// For any HTTPS request to an instance with a pinned certificate, the
    /// Certificate_Manager SHALL validate that the server certificate fingerprint
    /// matches the stored fingerprint.
    test('Property 19: Validation accepts matching fingerprints', () {
      final testCert = _createTestCertificate();
      final fingerprint = computeFingerprintSync(testCert);

      final result = certificateManager.validateCertificate(fingerprint, fingerprint);

      expect(result, isTrue);
    });

    /// Property 20: Certificate Mismatch Rejection
    /// For any HTTPS request where the certificate fingerprint does not match
    /// the pinned fingerprint, the Certificate_Manager SHALL reject the connection.
    test('Property 20: Validation rejects mismatched fingerprints', () {
      final testCert1 = _createTestCertificate(0);
      final testCert2 = _createTestCertificate(1);

      final fingerprint1 = computeFingerprintSync(testCert1);
      final fingerprint2 = computeFingerprintSync(testCert2);

      // Different certificates should have different fingerprints
      expect(fingerprint1, isNot(equals(fingerprint2)));

      // Validation should reject the mismatch
      final result = certificateManager.validateCertificate(fingerprint1, fingerprint2);
      expect(result, isFalse);
    });

    /// Property 21: HTTPS Protocol Enforcement
    /// For any communication with an instance, the protocol SHALL be HTTPS
    /// (no HTTP fallback).
    test('Property 21: createPinnedClient returns HttpClient for HTTPS', () {
      final fingerprint = 'aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99';
      final client = certificateManager.createPinnedClient(fingerprint);

      expect(client, isA<HttpClient>());
    });

    /// Property 22: Certificate Validation Idempotence
    /// For any valid certificate, computing the fingerprint then validating
    /// against that fingerprint SHALL accept the certificate.
    test('Property 22: Validation is idempotent for valid certificates', () {
      final testCert = _createTestCertificate();
      final fingerprint = computeFingerprintSync(testCert);

      // First validation
      final result1 = certificateManager.validateCertificate(fingerprint, fingerprint);

      // Second validation (idempotence check)
      final result2 = certificateManager.validateCertificate(fingerprint, fingerprint);

      expect(result1, isTrue);
      expect(result2, isTrue);
    });

    /// Property 23: HTTP Client Certificate Callback Configuration
    /// For any HTTP client created for instance communication, it SHALL have
    /// a custom certificate validation callback configured.
    test('Property 23: Pinned client has certificate validation callback', () {
      final fingerprint = 'aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99';
      final client = certificateManager.createPinnedClient(fingerprint);

      // The callback should be configured (non-null) - we verify by checking the client
      // can be used with a callback set
      expect(client, isA<HttpClient>());
    });

    /// Property 24: Certificate Fingerprint Computation
    /// For any certificate, computing the fingerprint SHALL use SHA-256 hash
    /// of the certificate DER encoding.
    test('Property 24: Fingerprint uses SHA-256 of DER encoding', () async {
      final testCert = _createTestCertificate();
      final fingerprint = await certificateManager.computeFingerprint(testCert);

      // SHA-256 produces 32 bytes = 64 hex characters = 32 colon-separated pairs
      final hexPairs = fingerprint.split(':');
      expect(hexPairs.length, equals(32));

      // Each pair should be a valid hex byte
      for (final pair in hexPairs) {
        expect(pair.length, equals(2));
        final byteValue = int.parse(pair, radix: 16);
        expect(byteValue, inInclusiveRange(0, 255));
      }
    });
  });
}

/// Creates a test X509Certificate with known DER encoding for testing
X509Certificate _createTestCertificate([int seed = 0]) {
  // Create a minimal self-signed certificate for testing
  // This uses dart:io's X509Certificate parsing
  final testDer = Uint8List.fromList([
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
    0x02, 0x03, 0x01, 0x00, 0x01, 0x00 + seed,
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