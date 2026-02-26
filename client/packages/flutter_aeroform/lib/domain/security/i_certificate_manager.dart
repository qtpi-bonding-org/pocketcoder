import 'dart:io';

/// Abstract interface for certificate management and pinning
abstract class ICertificateManager {
  /// Retrieves certificate fingerprint from HTTPS endpoint
  Future<String> retrieveCertificateFingerprint(String host, {int port = 443});

  /// Creates HTTP client with certificate pinning validation
  HttpClient createPinnedClient(String expectedFingerprint);

  /// Validates certificate against expected fingerprint
  bool validateCertificate(String expectedFingerprint, String actualFingerprint);

  /// Computes SHA-256 fingerprint from certificate
  Future<String> computeFingerprint(X509Certificate certificate);

  /// Stores certificate fingerprint securely
  Future<void> storeFingerprint(String instanceId, String fingerprint);

  /// Retrieves stored certificate fingerprint
  Future<String?> getFingerprint(String instanceId);
}