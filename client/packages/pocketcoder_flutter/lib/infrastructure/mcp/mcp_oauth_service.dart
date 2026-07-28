import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_oauth_service.dart';

/// Shape of FlutterWebAuth2.authenticate, injected so tests can substitute
/// a fake without a real platform channel — same call shape as
/// flutter_aeroform's LinodeOAuthService.authenticate(), but injected
/// directly rather than via that file's dynamic-import mocking hack.
typedef WebAuthLauncher = Future<String> Function({
  required String url,
  required String callbackUrlScheme,
});

/// Cloudflare-Worker-backed OAuth client for locally-run MCP catalog
/// servers that need a real user identity (GitHub today) rather than a
/// static API key. See i_mcp_oauth_service.dart's doc comment and
/// docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md Component 2.
///
/// `provider` is a per-call argument, not a constructor argument, even
/// though the spec's illustrative pseudocode shows
/// `McpOAuthService(provider: 'github')` — this class is a DI singleton
/// (registered once via @LazySingleton below, matching every other
/// single-implementation infrastructure class in this package, e.g.
/// AuthRepository/FilesRepository), so it can't be constructed fresh per
/// provider. The Worker and this provider registry are already generic by
/// construction, so a method parameter does the same job.
@LazySingleton(as: IMcpOAuthService)
class McpOAuthService implements IMcpOAuthService {
  static const _callbackScheme = 'pocketcoder';

  // Deliberately duplicated (not shared) with workers/mcp-oauth-relay's own
  // PROVIDERS map: the Worker never builds this authorize URL itself
  // (Decision 1 — no /start round trip), so the two registries only need
  // to describe the same OAuth Apps, not share code. Out of scope:
  // providers other than GitHub (see the spec's Out of scope section).
  static const _authorizeUrls = {
    'github': 'https://github.com/login/oauth/authorize',
  };
  static const _scopes = {
    'github': 'repo read:user',
  };

  final http.Client _httpClient;
  final String _relayBaseUrl;
  final Map<String, String> _clientIds;

  McpOAuthService(
    this._httpClient,
    @Named('mcpOAuthRelayBaseUrl') this._relayBaseUrl,
    @Named('githubOAuthClientId') String githubClientId,
  ) : _clientIds = {'github': githubClientId};

  /// Overridable in tests only — production code always uses the real
  /// FlutterWebAuth2.authenticate.
  @visibleForTesting
  WebAuthLauncher webAuthLauncher = FlutterWebAuth2.authenticate;

  @override
  Future<McpOAuthTokenPair> authenticate(String provider) {
    return tryMethod(() async {
      final authorizeUrl = _authorizeUrls[provider];
      final clientId = _clientIds[provider];
      final scope = _scopes[provider];
      if (authorizeUrl == null || clientId == null || scope == null) {
        throw McpOAuthException.unknownProvider(provider);
      }

      final codeVerifier = generateCodeVerifier();
      final codeChallenge = generateCodeChallenge(codeVerifier);
      final state = encodeState(provider: provider, codeChallenge: codeChallenge);
      final redirectUri = '$_relayBaseUrl/callback';

      final authUri = Uri.parse(authorizeUrl).replace(queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'scope': scope,
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      });

      String callbackUrl;
      try {
        callbackUrl = await webAuthLauncher(
          url: authUri.toString(),
          callbackUrlScheme: _callbackScheme,
        );
      } on PlatformException catch (e) {
        if (e.code == 'CANCELED') {
          throw McpOAuthException.cancelled();
        }
        throw McpOAuthException('Web auth failed: ${e.code}', e);
      }

      final callback = Uri.parse(callbackUrl);
      final providerError = callback.queryParameters['error'];
      if (providerError != null) {
        throw McpOAuthException.providerError(providerError);
      }
      final exchangeCode = callback.queryParameters['exchange_code'];
      if (exchangeCode == null || exchangeCode.isEmpty) {
        throw McpOAuthException('Worker callback missing exchange_code');
      }

      return _claim(exchangeCode: exchangeCode, codeVerifier: codeVerifier);
    }, McpOAuthException.new, 'authenticate');
  }

  Future<McpOAuthTokenPair> _claim({
    required String exchangeCode,
    required String codeVerifier,
  }) async {
    final resp = await _httpClient.post(
      Uri.parse('$_relayBaseUrl/claim'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'exchange_code': exchangeCode,
        'code_verifier': codeVerifier,
      }),
    );

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw McpOAuthException.claimFailed(body['error']);
    }
    final accessToken = body['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw McpOAuthException.claimFailed('missing access_token in /claim response');
    }
    return (accessToken: accessToken, refreshToken: body['refresh_token'] as String?);
  }

  /// PKCE code_verifier per RFC 7636: 43-128 chars, unreserved charset.
  @visibleForTesting
  static String generateCodeVerifier() {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(64, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// S256 code_challenge: SHA-256 of the verifier, base64url without
  /// padding — the same transform workers/mcp-oauth-relay's /claim route
  /// re-derives from the verifier the app sends back.
  @visibleForTesting
  static String generateCodeChallenge(String codeVerifier) {
    final hash = sha256.convert(utf8.encode(codeVerifier));
    return base64Url.encode(hash.bytes).replaceAll('=', '');
  }

  /// Encodes {p: provider, cc: code_challenge} as base64url(JSON) into the
  /// OAuth `state` param. The Worker only ever decodes this at /callback
  /// time (see workers/mcp-oauth-relay/src/index.js's parseState).
  /// Plaintext, not HMAC-signed: code_challenge is not secret (RFC 7636
  /// §4.2) — see this plan's Global Constraints, Decision 1.
  @visibleForTesting
  static String encodeState({required String provider, required String codeChallenge}) {
    final json = jsonEncode({'p': provider, 'cc': codeChallenge});
    return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
  }
}
