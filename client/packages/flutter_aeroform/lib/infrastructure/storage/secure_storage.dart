import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_aeroform/domain/models/instance_credentials.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';

/// Secure storage implementation using platform-specific secure storage
/// (iOS Keychain, Android Keystore)
@LazySingleton(as: ISecureStorage)
class SecureStorage implements ISecureStorage {
  final FlutterSecureStorage _storage;

  // Storage keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpirationKey = 'token_expiration';
  static const String _codeVerifierKey = 'code_verifier';
  static const String _instanceCredentialsPrefix = 'instance_credentials_';
  static const String _certificateFingerprintPrefix = 'certificate_fingerprint_';

  SecureStorage({required FlutterSecureStorage storage}) : _storage = storage;

  @override
  Future<void> storeAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  @override
  Future<void> storeRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  @override
  Future<void> storeTokenExpiration(DateTime expiresAt) async {
    await _storage.write(
      key: _tokenExpirationKey,
      value: expiresAt.toIso8601String(),
    );
  }

  @override
  Future<DateTime?> getTokenExpiration() async {
    final expiresAt = await _storage.read(key: _tokenExpirationKey);
    if (expiresAt == null) return null;
    return DateTime.parse(expiresAt);
  }

  @override
  Future<void> storeCodeVerifier(String codeVerifier) async {
    await _storage.write(key: _codeVerifierKey, value: codeVerifier);
  }

  @override
  Future<String?> getCodeVerifier() async {
    return await _storage.read(key: _codeVerifierKey);
  }

  @override
  Future<void> storeInstanceCredentials(InstanceCredentials credentials) async {
    final key = '$_instanceCredentialsPrefix${credentials.instanceId}';
    await _storage.write(
      key: key,
      value: jsonEncode(credentials.toJson()),
    );
  }

  @override
  Future<InstanceCredentials?> getInstanceCredentials(String instanceId) async {
    final key = '$_instanceCredentialsPrefix$instanceId';
    final json = await _storage.read(key: key);
    if (json == null) return null;
    return InstanceCredentials.fromJson(jsonDecode(json));
  }

  @override
  Future<void> storeCertificateFingerprint(
    String instanceId,
    String fingerprint,
  ) async {
    final key = '$_certificateFingerprintPrefix$instanceId';
    await _storage.write(key: key, value: fingerprint);
  }

  @override
  Future<String?> getCertificateFingerprint(String instanceId) async {
    final key = '$_certificateFingerprintPrefix$instanceId';
    return await _storage.read(key: key);
  }

  @override
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}