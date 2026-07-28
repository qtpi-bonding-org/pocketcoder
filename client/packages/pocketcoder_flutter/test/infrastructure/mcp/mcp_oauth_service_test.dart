import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_oauth_service.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  late McpOAuthService service;
  late MockHttpClient httpClient;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    httpClient = MockHttpClient();
    service = McpOAuthService(
      httpClient,
      'https://relay.example.com',
      'test-github-client-id',
    );
  });

  group('PKCE helpers', () {
    test('generateCodeVerifier produces a 64-char unreserved-charset string', () {
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

    test('encodeState round-trips provider + code_challenge', () {
      final state = McpOAuthService.encodeState(
        provider: 'github',
        codeChallenge: 'abc123',
      );
      final padded = base64Url.normalize(state);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(padded)));
      expect(decoded, {'p': 'github', 'cc': 'abc123'});
    });
  });

  group('McpOAuthService.authenticate', () {
    test('cancelled browser sheet surfaces isCancelled=true', () async {
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) {
        throw PlatformException(code: 'CANCELED');
      };

      try {
        await service.authenticate('github');
        fail('expected McpOAuthException');
      } on McpOAuthException catch (e) {
        expect(e.isCancelled, isTrue);
      }
    });

    test('provider error in the callback URL surfaces as McpOAuthException', () async {
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
        return 'pocketcoder://oauth-callback?error=access_denied';
      };

      await expectLater(
        () => service.authenticate('github'),
        throwsA(isA<McpOAuthException>().having((e) => e.isCancelled, 'isCancelled', isFalse)),
      );
    });

    test('unknown provider throws before launching the browser', () async {
      var launched = false;
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
        launched = true;
        return '';
      };

      await expectLater(
        () => service.authenticate('unknown-provider'),
        throwsA(isA<McpOAuthException>()),
      );
      expect(launched, isFalse);
    });

    test('happy path calls /claim with the generated code_verifier and returns the token pair', () async {
      String? capturedBody;
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
        final uri = Uri.parse(url);
        expect(uri.host, 'github.com');
        expect(uri.queryParameters['code_challenge_method'], 'S256');
        return 'pocketcoder://oauth-callback?exchange_code=xyz&state=${uri.queryParameters['state']}';
      };
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#body] as String;
        return http.Response(jsonEncode({'access_token': 'tok', 'refresh_token': 'ref'}), 200);
      });

      final pair = await service.authenticate('github');

      expect(pair.accessToken, 'tok');
      expect(pair.refreshToken, 'ref');
      final sentBody = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(sentBody['exchange_code'], 'xyz');
      expect(sentBody['code_verifier'], isNotEmpty);
    });

    test('/claim non-200 response throws McpOAuthException', () async {
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
        final uri = Uri.parse(url);
        return 'pocketcoder://oauth-callback?exchange_code=xyz&state=${uri.queryParameters['state']}';
      };
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response(jsonEncode({'error': 'verifier_mismatch'}), 400));

      await expectLater(() => service.authenticate('github'), throwsA(isA<McpOAuthException>()));
    });
  });
}
