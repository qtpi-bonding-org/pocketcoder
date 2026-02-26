import 'dart:io';


import 'package:crypto/crypto.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_aeroform/domain/security/i_certificate_manager.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';

/// Certificate validation error with user-friendly message
class CertificateValidationError extends Error {
  final String message;
  CertificateValidationError(this.message);
  @override
  String toString() => message;
}

/// Certificate manager implementation for SSL certificate retrieval and pinning
@LazySingleton(as: ICertificateManager)
class CertificateManager implements ICertificateManager {
  final ISecureStorage _secureStorage;

  CertificateManager(this._secureStorage);

  /// Retrieves certificate fingerprint from HTTPS endpoint
  /// Accepts any certificate during initial retrieval to get the fingerprint
  @override
  Future<String> retrieveCertificateFingerprint(String host, {int port = 443}) async {
    final socket = await SecureSocket.connect(
      host,
      port,
      onBadCertificate: (_) => true, // Accept any certificate for initial retrieval
    );

    final certificate = socket.peerCertificate;
    if (certificate == null) {
      throw CertificateValidationError('Failed to retrieve certificate from $host');
    }
    final fingerprint = await computeFingerprint(certificate);
    socket.close();

    return fingerprint;
  }

  /// Creates HTTP client with certificate pinning validation
  @override
  HttpClient createPinnedClient(String expectedFingerprint) {
    final client = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // For pinned clients, always validate against expected fingerprint
        final actualFingerprint = computeFingerprintSync(cert);
        return actualFingerprint == expectedFingerprint;
      };

    return client;
  }

  /// Validates certificate against expected fingerprint
  @override
  bool validateCertificate(String expectedFingerprint, String actualFingerprint) {
    return expectedFingerprint.toLowerCase() == actualFingerprint.toLowerCase();
  }

  /// Computes SHA-256 fingerprint from certificate
  @override
  Future<String> computeFingerprint(X509Certificate certificate) async {
    return computeFingerprintSync(certificate);
  }

  /// Stores certificate fingerprint securely
  @override
  Future<void> storeFingerprint(String instanceId, String fingerprint) async {
    await _secureStorage.storeCertificateFingerprint(instanceId, fingerprint);
  }

  /// Retrieves stored certificate fingerprint
  @override
  Future<String?> getFingerprint(String instanceId) async {
    return _secureStorage.getCertificateFingerprint(instanceId);
  }
}

/// Computes SHA-256 fingerprint of certificate DER encoding synchronously
String computeFingerprintSync(X509Certificate certificate) {
  final derBytes = certificate.der;
  final hash = sha256.convert(derBytes);
  return _formatFingerprint(hash.toString());
}

/// Formats fingerprint as colon-separated hex pairs
String _formatFingerprint(String hexString) {
  final buffer = StringBuffer();
  for (int i = 0; i < hexString.length; i += 2) {
    if (buffer.isNotEmpty) buffer.write(':');
    buffer.write(hexString.substring(i, i + 2));
  }
  return buffer.toString();
}