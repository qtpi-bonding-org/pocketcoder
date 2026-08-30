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
/// static API key. See i_mcp_oauth_service.dart's doc comment.
///
/// `provider` is a per-call argument, not a constructor argument — this
/// class is a DI singleton (registered once via @LazySingleton below,
/// matching every other single-implementation infrastructure class in
/// this package, e.g. AuthRepository/FilesRepository), so it can't be
/// constructed fresh per provider. It holds no per-provider config at all
/// (see the provider-discovery spec) — the Worker's GET /authorize route
/// builds the real authorize URL server-side, so this class only ever
/// needs the opaque provider id string.
@LazySingleton(as: IMcpOAuthService)
class McpOAuthService implements IMcpOAuthService {
  static const _callbackScheme = 'pocketcoder';

  final http.Client _httpClient;
  final String _relayBaseUrl;

  McpOAuthService(
    this._httpClient,
    @Named('oauthRelayBaseUrl') this._relayBaseUrl,
  );

  /// Overridable in tests only — production code always uses the real
  /// FlutterWebAuth2.authenticate.
  @visibleForTesting
  WebAuthLauncher webAuthLauncher = FlutterWebAuth2.authenticate;

  /// In-memory cache, populated on first successful supportedProviders()
  /// call. Never populated from a failed fetch — a transient network
  /// failure must not poison the app session with an empty list that
  /// silently disables every CONNECT button until restart.
  List<McpOAuthProvider>? _cachedProviders;

  @override
  Future<List<McpOAuthProvider>> supportedProviders() {
    return tryMethod(() async {
      final cached = _cachedProviders;
      if (cached != null) return cached;

      final resp = await _httpClient.get(Uri.parse('$_relayBaseUrl/providers'));
      if (resp.statusCode != 200) {
        throw McpOAuthException('Failed to fetch supported providers: ${resp.statusCode}');
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final rawList = body['providers'] as List<dynamic>? ?? const [];
      final providers = rawList.map((raw) {
        final map = raw as Map<String, dynamic>;
        return (id: map['id'] as String, displayName: map['displayName'] as String);
      }).toList();

      _cachedProviders = providers;
      return providers;
    }, McpOAuthException.new, 'supportedProviders');
  }

  @override
  Future<McpOAuthTokenPair> authenticate(String provider) {
    return tryMethod(() async {
      final codeVerifier = generateCodeVerifier();
      final codeChallenge = generateCodeChallenge(codeVerifier);

      final authorizeUri = Uri.parse('$_relayBaseUrl/authorize').replace(queryParameters: {
        'provider': provider,
        'code_challenge': codeChallenge,
      });

      String callbackUrl;
      try {
        callbackUrl = await webAuthLauncher(
          url: authorizeUri.toString(),
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

      // Defense in depth: the Worker now builds `state` itself (see the
      // provider-discovery spec), so this client-side check doesn't
      // protect anything /claim's own PKCE verifier check doesn't already
      // cover — but it's free, catches a spoofed deep-link one hop
      // earlier, and restores the property `state` is normally for
      // (RFC 6749 §10.12: the initiator verifies the response corresponds
      // to its own request).
      final stateParam = callback.queryParameters['state'];
      final decodedState = stateParam == null ? null : decodeState(stateParam);
      if (decodedState == null ||
          decodedState['cc'] != codeChallenge ||
          decodedState['p'] != provider) {
        throw McpOAuthException.stateMismatch();
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
  /// padding — the same transform workers/oauth-relay's /claim route
  /// re-derives from the verifier the app sends back.
  @visibleForTesting
  static String generateCodeChallenge(String codeVerifier) {
    final hash = sha256.convert(utf8.encode(codeVerifier));
    return base64Url.encode(hash.bytes).replaceAll('=', '');
  }

  /// Decodes the `state` param the Worker's GET /authorize route built
  /// (base64url(JSON.stringify({p, cc}))) — see
  /// workers/oauth-relay/src/index.js's handleAuthorize. Returns null
  /// on any malformed input rather than throwing, since this is used for
  /// a defense-in-depth equality check, not a required-to-succeed parse.
  @visibleForTesting
  static Map<String, dynamic>? decodeState(String stateParam) {
    try {
      final padded = base64Url.normalize(stateParam);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(padded)));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      return null;
    }
  }
}
