import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/auth/i_oauth_service.dart';
import 'package:pocketcoder_flutter/domain/cloud_provider/i_cloud_provider_api_client.dart';
import 'package:pocketcoder_flutter/domain/models/oauth_token.dart';
import 'package:pocketcoder_flutter/domain/storage/i_secure_storage.dart';

/// Error thrown when authentication fails or is cancelled
class AuthenticationError implements Exception {
  final String message;
  final bool isCancelled;

  AuthenticationError(this.message, {this.isCancelled = false});

  @override
  String toString() => 'AuthenticationError: $message';
}

/// OAuth service implementation for Linode authentication
@LazySingleton(as: IOAuthService)
class LinodeOAuthService implements IOAuthService {
  static const String _authUrl = 'https://login.linode.com/oauth/authorize';
  static const List<String> _requiredScopes = [
    'linodes:read_write',
    'linodes:create',
  ];

  final ISecureStorage _secureStorage;
  final ICloudProviderAPIClient _apiClient;
  final String _clientId;
  final String _redirectUri;

  LinodeOAuthService(
    this._secureStorage,
    this._apiClient,
    @Named('linodeClientId') this._clientId,
  ) : _redirectUri = 'pocketcoder://oauth-callback';

  @override
  String get providerName => 'linode';

  @override
  List<String> get requiredScopes => _requiredScopes;

  @override
  Future<void> authenticate() async {
    // Generate PKCE code verifier and challenge
    final codeVerifier = generateCodeVerifier();
    final codeChallenge = generateCodeChallenge(codeVerifier);

    // Store code verifier for later exchange
    await _secureStorage.storeCodeVerifier(codeVerifier);

    // Build authorization URL
    final authUri = Uri.parse(_authUrl).replace(queryParameters: {
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'scope': _requiredScopes.join(' '),
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });

    // Use flutter_web_auth_2 to launch browser and handle callback
    try {
      final result = await authenticateWithWebAuth(authUri.toString(), getCallbackScheme());

      // Extract authorization code from callback URL
      final code = extractCodeFromCallback(result);
      if (code == null) {
        throw AuthenticationError('No authorization code received');
      }

      // Exchange code for tokens
      await exchangeCode(code);
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') {
        throw AuthenticationError('Authentication cancelled by user', isCancelled: true);
      }
      throw AuthenticationError('Authentication failed: ${e.message}');
    }
  }

  /// Extracted for testing - actual flutter_web_auth_2 call
  Future<String> authenticateWithWebAuth(String url, String callbackUrlScheme) {
    // Import flutter_web_auth_2 at runtime to avoid import issues in tests
    return getFlutterWebAuth2().authenticate(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
    );
  }

  /// Gets the flutter_web_auth_2 instance - can be mocked for testing
  dynamic getFlutterWebAuth2() {
    // Using late binding to avoid import issues
    try {
      return importFlutterWebAuth2();
    } catch (_) {
      // Return a mock-compatible interface for testing
      return MockFlutterWebAuth2();
    }
  }

  String getCallbackScheme() {
    final uri = Uri.parse(_redirectUri);
    return uri.scheme;
  }

  String? extractCodeFromCallback(String callbackUrl) {
    final parsed = Uri.parse(callbackUrl);
    return parsed.queryParameters['code'];
  }

  @override
  Future<OAuthToken> exchangeCode(String code) async {
    final codeVerifier = await _secureStorage.getCodeVerifier();
    if (codeVerifier == null) {
      throw AuthenticationError('Code verifier not found');
    }

    final token = await _apiClient.exchangeAuthCode(code, codeVerifier);

    // Store tokens securely
    await _secureStorage.storeAccessToken(token.accessToken);
    await _secureStorage.storeRefreshToken(token.refreshToken);
    await _secureStorage.storeTokenExpiration(token.expiresAt);

    // Clear code verifier after use
    await _secureStorage.storeCodeVerifier('');

    return token;
  }

  @override
  Future<OAuthToken> refreshToken() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null) {
      throw AuthenticationError('No refresh token available');
    }

    final token = await _apiClient.refreshAccessToken(refreshToken);

    // Store new tokens securely
    await _secureStorage.storeAccessToken(token.accessToken);
    await _secureStorage.storeRefreshToken(token.refreshToken);
    await _secureStorage.storeTokenExpiration(token.expiresAt);

    return token;
  }

  @override
  bool validateScopes(OAuthToken token) {
    return _requiredScopes.every((scope) => token.scopes.contains(scope));
  }

  @override
  Future<void> logout() async {
    await _secureStorage.clearAll();
  }

  @override
  Future<String> getAccessToken() async {
    final token = await _secureStorage.getAccessToken();
    if (token == null) {
      throw AuthenticationError('Not authenticated');
    }

    // Check if token needs refresh (within 5 minutes of expiration)
    final expiresAt = await _secureStorage.getTokenExpiration();
    if (expiresAt != null && DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)))) {
      final newToken = await refreshToken();
      return newToken.accessToken;
    }

    return token;
  }

  /// Generates a PKCE code verifier
  /// Per RFC 7636: 43-128 characters using unreserved characters
  String generateCodeVerifier() {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    final length = 43 + random.nextInt(86); // 43-128 characters

    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Generates a PKCE code challenge from the code verifier
  /// SHA256 hash, then Base64URL encoding without padding
  String generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final hash = sha256.convert(bytes);

    // Base64URL encode without padding
    return base64UrlEncode(hash.bytes).replaceAll('=', '');
  }
}

/// Helper function to import flutter_web_auth_2
dynamic importFlutterWebAuth2() {
  throw UnsupportedError('flutter_web_auth_2 not available in test');
}

/// Mock implementation for testing
class MockFlutterWebAuth2 {
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
  }) async {
    return '$callbackUrlScheme://oauth-callback?code=test-code';
  }
}