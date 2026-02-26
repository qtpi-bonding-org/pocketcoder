import 'package:flutter_aeroform/domain/models/instance_credentials.dart';

/// Abstract interface for secure credential storage
abstract class ISecureStorage {
  /// Stores OAuth access token
  Future<void> storeAccessToken(String token);

  /// Retrieves OAuth access token
  Future<String?> getAccessToken();

  /// Stores OAuth refresh token
  Future<void> storeRefreshToken(String token);

  /// Retrieves OAuth refresh token
  Future<String?> getRefreshToken();

  /// Stores token expiration timestamp
  Future<void> storeTokenExpiration(DateTime expiresAt);

  /// Retrieves token expiration timestamp
  Future<DateTime?> getTokenExpiration();

  /// Stores PKCE code verifier
  Future<void> storeCodeVerifier(String codeVerifier);

  /// Retrieves PKCE code verifier
  Future<String?> getCodeVerifier();

  /// Stores instance credentials
  Future<void> storeInstanceCredentials(InstanceCredentials credentials);

  /// Retrieves instance credentials
  Future<InstanceCredentials?> getInstanceCredentials(String instanceId);

  /// Stores certificate fingerprint
  Future<void> storeCertificateFingerprint(String instanceId, String fingerprint);

  /// Retrieves certificate fingerprint
  Future<String?> getCertificateFingerprint(String instanceId);

  /// Clears all stored data
  Future<void> clearAll();
}