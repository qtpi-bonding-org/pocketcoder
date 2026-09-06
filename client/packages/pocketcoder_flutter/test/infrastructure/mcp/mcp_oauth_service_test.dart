import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_oauth_service.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

/// Builds a Worker-shaped `state` param the way
/// workers/oauth-relay/src/index.js's handleAuthorize does, for tests
/// that need to simulate a well-formed provider callback.
String _encodeStateForTest(
    {required String provider, required String codeChallenge}) {
  final json = jsonEncode({'p': provider, 'cc': codeChallenge});
  return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
}

void main() {
  late McpOAuthService service;
  late MockHttpClient httpClient;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    httpClient = MockHttpClient();
    service = McpOAuthService(httpClient, 'https://relay.example.com');
  });

  group('PKCE helpers', () {
    test('generateCodeVerifier produces a 64-char unreserved-charset string',
        () {
      final v = McpOAuthService.generateCodeVerifier();
      expect(v.length, 64);
      expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(v), isTrue);
    });

    test('generateCodeChallenge is deterministic S256 of the verifier', () {
      const verifier = 'fixed-test-verifier-value-1234567890';
      final a = McpOAuthService.generateCodeChallenge(verifier);
      final b = McpOAuthService.generateCodeChallenge(verifier);
      expect(a, b);
      expect(a, isNot(contains('=')));
    });

    test('decodeState round-trips a Worker-shaped state param', () {
      final state =
          _encodeStateForTest(provider: 'github', codeChallenge: 'abc123');
      final decoded = McpOAuthService.decodeState(state);
      expect(decoded, {'p': 'github', 'cc': 'abc123'});
    });

    test('decodeState returns null for malformed input', () {
      expect(McpOAuthService.decodeState('not-valid-base64url-json'), isNull);
    });
  });

  group('McpOAuthService.supportedProviders', () {
    test('fetches and parses the provider list, then caches it', () async {
      when(() => httpClient.get(any())).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'providers': [
              {'id': 'github', 'displayName': 'GitHub'},
            ],
          }),
          200,
        ),
      );

      final first = await service.supportedProviders();
      final second = await service.supportedProviders();

      expect(first, [(id: 'github', displayName: 'GitHub')]);
      expect(second, first);
      verify(() => httpClient.get(any()))
          .called(1); // second call served from cache
    });

    test('does not cache a failed fetch — a later call retries', () async {
      when(() => httpClient.get(any()))
          .thenAnswer((_) async => http.Response('', 500));

      await expectLater(() => service.supportedProviders(),
          throwsA(isA<McpOAuthException>()));

      when(() => httpClient.get(any())).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'providers': [
              {'id': 'github', 'displayName': 'GitHub'},
            ],
          }),
          200,
        ),
      );
      final result = await service.supportedProviders();

      expect(result, [(id: 'github', displayName: 'GitHub')]);
      verify(() => httpClient.get(any()))
          .called(2); // first (failed) + second (succeeded)
    });
  });

  group('McpOAuthService.authenticate', () {
    test('cancelled browser sheet surfaces isCancelled=true', () async {
      service.webAuthLauncher =
          ({required String url, required String callbackUrlScheme}) {
        throw PlatformException(code: 'CANCELED');
      };

      try {
        await service.authenticate('github');
        fail('expected McpOAuthException');
      } on McpOAuthException catch (e) {
        expect(e.isCancelled, isTrue);
      }
    });

    test('provider error in the callback URL surfaces as McpOAuthException',
        () async {
      service.webAuthLauncher =
          ({required String url, required String callbackUrlScheme}) async {
        return 'pocketcoder://oauth-callback?error=access_denied';
      };

      await expectLater(
        () => service.authenticate('github'),
        throwsA(isA<McpOAuthException>()
            .having((e) => e.isCancelled, 'isCancelled', isFalse)),
      );
    });

    test(
        'opens relayBaseUrl/authorize with provider and code_challenge — no local provider knowledge',
        () async {
      String? openedUrl;
      service.webAuthLauncher =
          ({required String url, required String callbackUrlScheme}) async {
        openedUrl = url;
        final uri = Uri.parse(url);
        final codeChallenge = uri.queryParameters['code_challenge'] ?? '';
        final state = _encodeStateForTest(
            provider: 'github', codeChallenge: codeChallenge);
        return 'pocketcoder://oauth-callback?exchange_code=xyz&state=$state';
      };
      when(() =>
          httpClient.post(any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'))).thenAnswer((_) async => http.Response(
          jsonEncode({'access_token': 'tok', 'refresh_token': 'ref'}), 200));

      final pair = await service.authenticate('github');

      final uri = Uri.parse(openedUrl!);
      expect(uri.host, 'relay.example.com');
      expect(uri.path, '/authorize');
      expect(uri.queryParameters['provider'], 'github');
      expect(uri.queryParameters['code_challenge'], isNotEmpty);
      expect(pair.accessToken, 'tok');
      expect(pair.refreshToken, 'ref');
    });

    test(
        'happy path calls /claim with the generated code_verifier and returns the token pair',
        () async {
      String? capturedBody;
      service.webAuthLauncher =
          ({required String url, required String callbackUrlScheme}) async {
        final uri = Uri.parse(url);
        final codeChallenge = uri.queryParameters['code_challenge'] ?? '';
        final state = _encodeStateForTest(
            provider: 'github', codeChallenge: codeChallenge);
        return 'pocketcoder://oauth-callback?exchange_code=xyz&state=$state';
      };
      when(() => httpClient.post(any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'))).thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#body] as String;
        return http.Response(
            jsonEncode({'access_token': 'tok', 'refresh_token': 'ref'}), 200);
      });

      final pair = await service.authenticate('github');

      expect(pair.accessToken, 'tok');
      expect(pair.refreshToken, 'ref');
      final sentBody = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(sentBody['exchange_code'], 'xyz');
      expect(sentBody['code_verifier'], isNotEmpty);
    });

    test('state mismatch throws before calling /claim', () async {
      service.webAuthLauncher =
          ({required String url, required String callbackUrlScheme}) async {
        // state decodes to a code_challenge that doesn't match what this
        // client generated — simulates a spoofed/mismatched deep link.
        final state = _encodeStateForTest(
            provider: 'github', codeChallenge: 'not-the-real-challenge');
        return 'pocketcoder://oauth-callback?exchange_code=xyz&state=$state';
      };

      await expectLater(() => service.authenticate('github'),
          throwsA(isA<McpOAuthException>()));
      verifyNever(() => httpClient.post(any(),
          headers: any(named: 'headers'), body: any(named: 'body')));
    });

    test('missing state throws before calling /claim', () async {
      service.webAuthLauncher =
          ({required String url, required String callbackUrlScheme}) async {
        return 'pocketcoder://oauth-callback?exchange_code=xyz';
      };

      await expectLater(() => service.authenticate('github'),
          throwsA(isA<McpOAuthException>()));
      verifyNever(() => httpClient.post(any(),
          headers: any(named: 'headers'), body: any(named: 'body')));
    });

    test('/claim non-200 response throws McpOAuthException', () async {
      service.webAuthLauncher =
          ({required String url, required String callbackUrlScheme}) async {
        final uri = Uri.parse(url);
        final codeChallenge = uri.queryParameters['code_challenge'] ?? '';
        final state = _encodeStateForTest(
            provider: 'github', codeChallenge: codeChallenge);
        return 'pocketcoder://oauth-callback?exchange_code=xyz&state=$state';
      };
      when(() => httpClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async =>
              http.Response(jsonEncode({'error': 'verifier_mismatch'}), 400));

      await expectLater(() => service.authenticate('github'),
          throwsA(isA<McpOAuthException>()));
    });
  });
}
