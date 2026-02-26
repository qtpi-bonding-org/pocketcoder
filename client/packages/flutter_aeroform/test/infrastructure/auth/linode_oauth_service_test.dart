



import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_aeroform/domain/cloud_provider/i_cloud_provider_api_client.dart';
import 'package:flutter_aeroform/domain/models/oauth_token.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:flutter_aeroform/infrastructure/auth/linode_oauth_service.dart';

class MockSecureStorage extends Mock implements ISecureStorage {}

class MockCloudProviderAPIClient extends Mock
    implements ICloudProviderAPIClient {}

void main() {
  late MockSecureStorage mockSecureStorage;
  late MockCloudProviderAPIClient mockApiClient;
  late LinodeOAuthService service;

  const testClientId = 'test-client-id';
  const testAccessToken = 'test-access-token';
  const testRefreshToken = 'test-refresh-token';

  setUpAll(() {
    registerFallbackValue(DateTime.now());
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    mockSecureStorage = MockSecureStorage();
    mockApiClient = MockCloudProviderAPIClient();

    // Default stubbing for secure storage
    when(() => mockSecureStorage.storeCodeVerifier(any()))
        .thenAnswer((_) async {});
    when(() => mockSecureStorage.getCodeVerifier())
        .thenAnswer((_) async => null);
    when(() => mockSecureStorage.storeAccessToken(any()))
        .thenAnswer((_) async {});
    when(() => mockSecureStorage.getAccessToken())
        .thenAnswer((_) async => null);
    when(() => mockSecureStorage.storeRefreshToken(any()))
        .thenAnswer((_) async {});
    when(() => mockSecureStorage.getRefreshToken())
        .thenAnswer((_) async => null);
    when(() => mockSecureStorage.storeTokenExpiration(any()))
        .thenAnswer((_) async {});
    when(() => mockSecureStorage.getTokenExpiration())
        .thenAnswer((_) async => null);
    when(() => mockSecureStorage.clearAll()).thenAnswer((_) async {});

    service = LinodeOAuthService(
      mockSecureStorage,
      mockApiClient,
      testClientId,
    );
  });

  group('LinodeOAuthService', () {
    group('providerName', () {
      test('returns linode', () {
        expect(service.providerName, equals('linode'));
      });
    });

    group('requiredScopes', () {
      test('returns correct scopes', () {
        expect(service.requiredScopes,
            equals(['linodes:read_write', 'linodes:create']));
      });
    });

    group('generateCodeVerifier', () {
      test('generates PKCE code verifier with correct length', () async {
        final codeVerifiers = <String>{};
        for (int i = 0; i < 100; i++) {
          final verifier = service.generateCodeVerifier();
          expect(verifier.length, greaterThanOrEqualTo(43));
          expect(verifier.length, lessThanOrEqualTo(128));
          codeVerifiers.add(verifier);
        }
        // Verify uniqueness
        expect(codeVerifiers.length, greaterThan(90));
      });

      test('generates PKCE code verifier with valid characters', () async {
        const validChars =
            'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
        for (int i = 0; i < 50; i++) {
          final verifier = service.generateCodeVerifier();
          for (final char in verifier.runes) {
            expect(validChars.contains(String.fromCharCode(char)), isTrue);
          }
        }
      });
    });

    group('generateCodeChallenge', () {
      test('generates consistent code challenge from verifier', () async {
        const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
        final challenge = service.generateCodeChallenge(verifier);

        // SHA256 of the verifier, Base64URL encoded
        expect(challenge, isNotEmpty);
        expect(challenge, isNot(equals(verifier)));
        // Should not contain padding
        expect(challenge.contains('='), isFalse);
      });

      test('generates different code challenges for different verifiers',
          () async {
        final challenges = <String>{};
        for (int i = 0; i < 10; i++) {
          final verifier = service.generateCodeVerifier();
          final challenge = service.generateCodeChallenge(verifier);
          challenges.add(challenge);
        }
        expect(challenges.length, equals(10));
      });

      test('matches expected challenge for known verifier', () {
        // This is a known test vector from RFC 7636
        const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
        final challenge = service.generateCodeChallenge(verifier);

        // Expected: E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
        expect(
            challenge, equals('E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM'));
      });
    });

    group('extractCodeFromCallback', () {
      test('extracts authorization code from callback URL', () {
        final code = service.extractCodeFromCallback(
            'pocketcoder://oauth-callback?code=auth123');
        expect(code, equals('auth123'));
      });

      test('returns null when no code in callback', () {
        final code = service.extractCodeFromCallback(
            'pocketcoder://oauth-callback?error=cancelled');
        expect(code, isNull);
      });

      test('handles URL with multiple parameters', () {
        final code = service.extractCodeFromCallback(
            'pocketcoder://oauth-callback?state=xyz&code=auth123&scope=read');
        expect(code, equals('auth123'));
      });
    });

    group('getCallbackScheme', () {
      test('extracts scheme from redirect URI', () {
        final scheme = service.getCallbackScheme();
        expect(scheme, equals('pocketcoder'));
      });
    });

    group('exchangeCode', () {
      test('exchanges code for tokens and stores them', () async {
        const code = 'auth-code-123';
        const codeVerifier = 'code-verifier-456';

        final expectedToken = OAuthToken(
          accessToken: testAccessToken,
          refreshToken: testRefreshToken,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          scopes: ['linodes:read_write', 'linodes:create'],
        );

        when(() => mockSecureStorage.getCodeVerifier())
            .thenAnswer((_) async => codeVerifier);
        when(() => mockApiClient.exchangeAuthCode(code, codeVerifier))
            .thenAnswer((_) async => expectedToken);

        final result = await service.exchangeCode(code);

        expect(result.accessToken, equals(testAccessToken));
        expect(result.refreshToken, equals(testRefreshToken));
        verify(() => mockSecureStorage.storeAccessToken(testAccessToken))
            .called(1);
        verify(() => mockSecureStorage.storeRefreshToken(testRefreshToken))
            .called(1);
        verify(() => mockSecureStorage.storeTokenExpiration(any())).called(1);
      });

      test('throws AuthenticationError when code verifier not found', () async {
        when(() => mockSecureStorage.getCodeVerifier())
            .thenAnswer((_) async => null);

        expect(
          () => service.exchangeCode('code'),
          throwsA(isA<AuthenticationError>()),
        );
      });

      test('clears code verifier after token exchange', () async {
        const code = 'auth-code-123';
        const codeVerifier = 'code-verifier-456';

        final expectedToken = OAuthToken(
          accessToken: testAccessToken,
          refreshToken: testRefreshToken,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          scopes: ['linodes:read_write', 'linodes:create'],
        );

        when(() => mockSecureStorage.getCodeVerifier())
            .thenAnswer((_) async => codeVerifier);
        when(() => mockApiClient.exchangeAuthCode(code, codeVerifier))
            .thenAnswer((_) async => expectedToken);

        await service.exchangeCode(code);

        // Code verifier should be cleared (stored as empty string)
        verify(() => mockSecureStorage.storeCodeVerifier('')).called(1);
      });
    });

    group('refreshToken', () {
      test('refreshes token and stores new tokens', () async {
        const oldRefreshToken = 'old-refresh-token';
        const newAccessToken = 'new-access-token';
        const newRefreshToken = 'new-refresh-token';

        final expectedToken = OAuthToken(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          scopes: ['linodes:read_write', 'linodes:create'],
        );

        when(() => mockSecureStorage.getRefreshToken())
            .thenAnswer((_) async => oldRefreshToken);
        when(() => mockApiClient.refreshAccessToken(oldRefreshToken))
            .thenAnswer((_) async => expectedToken);

        final result = await service.refreshToken();

        expect(result.accessToken, equals(newAccessToken));
        expect(result.refreshToken, equals(newRefreshToken));
        verify(() => mockSecureStorage.storeAccessToken(newAccessToken))
            .called(1);
        verify(() => mockSecureStorage.storeRefreshToken(newRefreshToken))
            .called(1);
      });

      test('throws AuthenticationError when no refresh token available',
          () async {
        when(() => mockSecureStorage.getRefreshToken())
            .thenAnswer((_) async => null);

        expect(
          () => service.refreshToken(),
          throwsA(isA<AuthenticationError>()),
        );
      });
    });

    group('validateScopes', () {
      test('returns true when token has all required scopes', () {
        final token = OAuthToken(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          scopes: ['linodes:read_write', 'linodes:create', 'extra:scope'],
        );

        expect(service.validateScopes(token), isTrue);
      });

      test('returns false when token missing required scopes', () {
        final token = OAuthToken(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          scopes: ['linodes:read_write'],
        );

        expect(service.validateScopes(token), isFalse);
      });

      test('returns false when token has no scopes', () {
        final token = OAuthToken(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          scopes: [],
        );

        expect(service.validateScopes(token), isFalse);
      });
    });

    group('logout', () {
      test('clears all stored tokens', () async {
        await service.logout();

        verify(() => mockSecureStorage.clearAll()).called(1);
      });
    });

    group('getAccessToken', () {
      test('returns stored access token when not expired', () async {
        when(() => mockSecureStorage.getAccessToken())
            .thenAnswer((_) async => testAccessToken);
        when(() => mockSecureStorage.getTokenExpiration()).thenAnswer(
            (_) async => DateTime.now().add(const Duration(hours: 1)));

        final result = await service.getAccessToken();

        expect(result, equals(testAccessToken));
        verifyNever(() => mockApiClient.refreshAccessToken(any()));
      });

      test('refreshes token when within 5 minutes of expiration', () async {
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

        when(() => mockSecureStorage.getAccessToken())
            .thenAnswer((_) async => testAccessToken);
        when(() => mockSecureStorage.getTokenExpiration())
            .thenAnswer((_) async => nearExpiration);
        when(() => mockSecureStorage.getRefreshToken())
            .thenAnswer((_) async => testRefreshToken);
        when(() => mockApiClient.refreshAccessToken(testRefreshToken))
            .thenAnswer((_) async => newToken);

        final result = await service.getAccessToken();

        // Should return the new token after refresh
        expect(result, equals(newAccessToken));
        verify(() => mockApiClient.refreshAccessToken(testRefreshToken))
            .called(1);
        verify(() => mockSecureStorage.storeAccessToken(newAccessToken))
            .called(1);
      });

      test('throws AuthenticationError when not authenticated', () async {
        when(() => mockSecureStorage.getAccessToken())
            .thenAnswer((_) async => null);

        expect(
          () => service.getAccessToken(),
          throwsA(isA<AuthenticationError>()),
        );
      });
    });
  });
}
