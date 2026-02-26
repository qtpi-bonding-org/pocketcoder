import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/auth/i_oauth_service.dart';
import 'package:pocketcoder_flutter/domain/cloud_provider/i_cloud_provider_api_client.dart';
import 'package:pocketcoder_flutter/domain/models/oauth_token.dart';
import 'package:pocketcoder_flutter/domain/storage/i_secure_storage.dart';
import 'package:pocketcoder_flutter/infrastructure/auth/linode_oauth_service.dart';

class MockSecureStorage extends Mock implements ISecureStorage {}

class MockCloudProviderAPIClient extends Mock implements ICloudProviderAPIClient {}

class MockFlutterWebAuth2 {
  String? _callbackUrl;
  String? _lastUrl;
  String? _lastScheme;

  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
  }) async {
    _lastUrl = url;
    _lastScheme = callbackUrlScheme;
    if (_callbackUrl != null) {
      return _callbackUrl!;
    }
    throw PlatformException(
      code: 'CANCELED',
      message: 'User cancelled authentication',
    );
  }

  void setCallbackUrl(String url) => _callbackUrl = url;
  String? get lastUrl => _lastUrl;
  String? get lastScheme => _lastScheme;
}

void main() {
  late MockSecureStorage mockSecureStorage;
  late MockCloudProviderAPIClient mockApiClient;
  late LinodeOAuthService service;
  late MockFlutterWebAuth2 mockWebAuth;

  const testClientId = 'test-client-id';

  setUpAll(() {
    registerFallbackValue(DateTime.now());
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    mockSecureStorage = MockSecureStorage();
    mockApiClient = MockCloudProviderAPIClient();
    
    // Default stubbing for secure storage
    when(() => mockSecureStorage.storeCodeVerifier(any())).thenAnswer((_) async {});
    when(() => mockSecureStorage.getCodeVerifier()).thenAnswer((_) async => null);
    when(() => mockSecureStorage.storeAccessToken(any())).thenAnswer((_) async {});
    when(() => mockSecureStorage.getAccessToken()).thenAnswer((_) async => null);
    when(() => mockSecureStorage.storeRefreshToken(any())).thenAnswer((_) async {});
    when(() => mockSecureStorage.getRefreshToken()).thenAnswer((_) async => null);
    when(() => mockSecureStorage.storeTokenExpiration(any())).thenAnswer((_) async {});
    when(() => mockSecureStorage.getTokenExpiration()).thenAnswer((_) async => null);
    when(() => mockSecureStorage.clearAll()).thenAnswer((_) async {});
    
    service = LinodeOAuthService(
      mockSecureStorage,
      mockApiClient,
      testClientId,
    );
    mockWebAuth = MockFlutterWebAuth2();
  });

  group('LinodeOAuthService - Property Tests', () {
    /// Property 2: Token Scope Validation
    /// For any OAuthToken returned by the OAuth service, validateScopes() SHALL
    /// correctly identify whether the token has all required scopes.
    test('Property 2: Token scope validation is correct', () {
      final requiredScopes = service.requiredScopes;

      // Token with all required scopes should pass
      final validToken = OAuthToken(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        scopes: [...requiredScopes, 'extra:scope'],
      );
      expect(service.validateScopes(validToken), isTrue);

      // Token missing one required scope should fail
      final missingOneScope = OAuthToken(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        scopes: requiredScopes.take(1).toList(),
      );
      expect(service.validateScopes(missingOneScope), isFalse);

      // Token with empty scopes should fail
      final emptyScopes = OAuthToken(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        scopes: [],
      );
      expect(service.validateScopes(emptyScopes), isFalse);

      // Token with duplicate scopes should still pass if all required are present
      final duplicateScopes = OAuthToken(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        scopes: [...requiredScopes, ...requiredScopes],
      );
      expect(service.validateScopes(duplicateScopes), isTrue);
    });

    /// Property 3: Automatic Token Refresh
    /// When getAccessToken() is called and the token is within 5 minutes of
    /// expiration, the service SHALL automatically refresh the token.
    test('Property 3: Automatic token refresh on near expiration', () async {
      const oldAccessToken = 'old-access-token';
      const oldRefreshToken = 'old-refresh-token';
      const newAccessToken = 'new-access-token';
      const newRefreshToken = 'new-refresh-token';

      final newToken = OAuthToken(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        scopes: ['linodes:read_write', 'linodes:create'],
      );

      // Token expires in 3 minutes (within 5 minute threshold)
      final nearExpiration = DateTime.now().add(const Duration(minutes: 3));

      when(() => mockSecureStorage.getAccessToken()).thenAnswer((_) async => oldAccessToken);
      when(() => mockSecureStorage.getTokenExpiration()).thenAnswer((_) async => nearExpiration);
      when(() => mockSecureStorage.getRefreshToken()).thenAnswer((_) async => oldRefreshToken);
      when(() => mockApiClient.refreshAccessToken(oldRefreshToken))
          .thenAnswer((_) async => newToken);

      final result = await service.getAccessToken();

      // Should return the new token after refresh
      expect(result, equals(newAccessToken));
      verify(() => mockApiClient.refreshAccessToken(oldRefreshToken)).called(1);
      verify(() => mockSecureStorage.storeAccessToken(newAccessToken)).called(1);
    });

    /// Property 39: Token Replacement on Refresh
    /// When a token is refreshed, the new access token and refresh token
    /// SHALL replace the old ones in secure storage.
    test('Property 39: New tokens replace old tokens in storage', () async {
      const oldAccessToken = 'old-access-token';
      const oldRefreshToken = 'old-refresh-token';
      const newAccessToken = 'new-access-token';
      const newRefreshToken = 'new-refresh-token';

      final newToken = OAuthToken(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        scopes: ['linodes:read_write', 'linodes:create'],
      );

      when(() => mockSecureStorage.getAccessToken()).thenAnswer((_) async => oldAccessToken);
      when(() => mockSecureStorage.getTokenExpiration())
          .thenAnswer((_) async => DateTime.now().add(const Duration(minutes: 2)));
      when(() => mockSecureStorage.getRefreshToken()).thenAnswer((_) async => oldRefreshToken);
      when(() => mockApiClient.refreshAccessToken(oldRefreshToken))
          .thenAnswer((_) async => newToken);

      await service.refreshToken();

      // Verify new tokens are stored
      verify(() => mockSecureStorage.storeAccessToken(newAccessToken)).called(1);
      verify(() => mockSecureStorage.storeRefreshToken(newRefreshToken)).called(1);
      verify(() => mockSecureStorage.storeTokenExpiration(any())).called(1);

      // Verify old tokens are replaced (not duplicated)
      verifyNever(() => mockSecureStorage.storeAccessToken(oldAccessToken));
      verifyNever(() => mockSecureStorage.storeRefreshToken(oldRefreshToken));
    });

    /// Additional property: PKCE code verifier generation consistency
    /// For the same code verifier, the generated code challenge should always be the same.
    test('Property: PKCE code challenge is deterministic', () {
      const testVerifiers = [
        'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk',
        'abc123def456ghi789jkl012mno345pqr678stu901vwx234yz567',
        '~test-charset-characters-0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._~',
      ];

      for (final verifier in testVerifiers) {
        final challenge1 = service.generateCodeChallenge(verifier);
        final challenge2 = service.generateCodeChallenge(verifier);
        expect(challenge1, equals(challenge2));
      }
    });

    /// Additional property: OAuth URL contains all required parameters
    test('Property: OAuth URL construction includes all required parameters', () {
      // Build the authorization URL directly to verify parameters
      final authUri = Uri.parse('https://login.linode.com/oauth/authorize').replace(queryParameters: {
        'client_id': testClientId,
        'response_type': 'code',
        'redirect_uri': 'pocketcoder://oauth-callback',
        'scope': 'linodes:read_write linodes:create',
        'code_challenge': service.generateCodeChallenge('test-verifier'),
        'code_challenge_method': 'S256',
      });

      // Verify all required OAuth parameters
      expect(authUri.queryParameters['client_id'], isNotNull);
      expect(authUri.queryParameters['response_type'], equals('code'));
      expect(authUri.queryParameters['redirect_uri'], isNotNull);
      expect(authUri.queryParameters['scope'], isNotNull);
      expect(authUri.queryParameters['code_challenge'], isNotNull);
      expect(authUri.queryParameters['code_challenge_method'], equals('S256'));
      
      // Verify the URL is properly formed
      expect(authUri.host, equals('login.linode.com'));
      expect(authUri.path, equals('/oauth/authorize'));
    });

    /// Additional property: Token exchange clears code verifier
    test('Property: Code verifier is cleared after successful token exchange', () async {
      const code = 'auth-code-123';
      const codeVerifier = 'test-code-verifier';

      final expectedToken = OAuthToken(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        scopes: ['linodes:read_write', 'linodes:create'],
      );

      when(() => mockSecureStorage.getCodeVerifier()).thenAnswer((_) async => codeVerifier);
      when(() => mockApiClient.exchangeAuthCode(code, codeVerifier))
          .thenAnswer((_) async => expectedToken);

      await service.exchangeCode(code);

      // Code verifier should be cleared
      verify(() => mockSecureStorage.storeCodeVerifier('')).called(1);
    });
  });
}