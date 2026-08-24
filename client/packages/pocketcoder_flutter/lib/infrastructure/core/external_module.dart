import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'auth_aware_http_client.dart';
import 'auth_store.dart';
import 'caddy_ca_pinning_http_client.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/caddy_ca_pin_store.dart';
import "package:pocketcoder_flutter/infrastructure/core/logger.dart";

@module
abstract class ExternalModule {
  final _authHttpState = AuthHttpState();
  CaddyCaPinningHttpClient? _caddyCaPinningHttpClient;
  CaddyCaPinStore? _caddyCaPinStore;

  @preResolve
  @singleton
  Future<PocketBase> get pocketBase async {
    logInfo('PocketBaseInit: Starting...');

    // Restore persisted server URL, or fall back to default
    const storage = FlutterSecureStorage();
    final savedUrl = await storage.read(key: 'pb_server_url');
    final baseUrl = savedUrl ?? 'http://127.0.0.1:8090';
    logDebug(
        'PocketBaseInit: Using URL: $baseUrl${savedUrl != null ? ' (restored)' : ' (default)'}');

    // Load Schema (for offline capabilities)
    String? schemaJson;
    try {
      logDebug('PocketBaseInit: Loading assets/pb_schema.json...');
      // Use package path to be robust across multi-package builds (especially Web)
      schemaJson = await rootBundle
          .loadString('packages/pocketcoder_flutter/assets/pb_schema.json');
      logDebug('PocketBaseInit: Schema loaded (${schemaJson.length} chars)');
    } catch (e) {
      logError(
          'PocketBaseInit: ⚠️ Warning - failed to load schema asset (as package)',
          e);
      // Fallback to direct path for local runs
      try {
        schemaJson = await rootBundle.loadString('assets/pb_schema.json');
        logDebug('PocketBaseInit: Schema loaded via direct path');
      } catch (e2) {
        logError('PocketBaseInit: ⚠️ Fallback direct path also failed', e2);
      }
    }

    // Create secure auth store (reuses storage from above)
    final authStoreConfig = AuthStoreConfig(storage);
    final authStore = authStoreConfig.createAuthStore();
    _authHttpState.configureDeployment(
      baseUrl,
      tokenProvider: () => authStore.token,
    );

    // Initialize PocketBase Drift Client with persistent auth
    final client = $PocketBase.database(
      baseUrl,
      requestPolicy: RequestPolicy.cacheAndNetwork,
      authStore: authStore,
      httpClientFactory: () => AuthAwareHttpClient(
        _authHttpState,
        inner: caddyCaPinningHttpClient,
      ),
    );

    if (schemaJson != null && schemaJson.isNotEmpty && schemaJson != '[]') {
      try {
        logDebug('PocketBaseInit: Decoding raw JSON string...');
        final decoded = jsonDecode(schemaJson);
        logDebug('PocketBaseInit: Decoded root type is ${decoded.runtimeType}');

        List<dynamic> schemaList;
        if (decoded is Map && decoded.containsKey('items')) {
          logDebug('PocketBaseInit: Found "items" array in root Map');
          schemaList = decoded['items'] as List<dynamic>;
        } else if (decoded is List) {
          logDebug('PocketBaseInit: Root is already a List array');
          schemaList = decoded;
        } else {
          throw FormatException(
              'Unexpected schema root type: ${decoded.runtimeType}. Expected Map with "items" or List.');
        }

        logDebug(
            'PocketBaseInit: Extracted ${schemaList.length} schema definitions');

        final reEncoded = jsonEncode(schemaList);
        logDebug(
            'PocketBaseInit: Re-encoded pure list to length ${reEncoded.length}');

        logDebug(
            'PocketBaseInit: Caching schema synchronously via drift client...');
        await client.cacheSchema(reEncoded);
        logDebug(
            'PocketBaseInit: Schema cached successfully inside pocketbase_drift!');
      } catch (e, stack) {
        logError('PocketBaseInit: ❌ CRITICAL - Error parsing or caching schema',
            e, stack);
      }
    } else {
      logWarning('PocketBaseInit: ⚠️ No valid schema found to cache');
    }

    logInfo('PocketBaseInit: Complete');
    return client;
  }

  @singleton
  AuthHttpState get authHttpState => _authHttpState;

  @singleton
  AuthStoreConfig get authStoreConfig {
    return AuthStoreConfig(const FlutterSecureStorage());
  }

  @singleton
  FlutterSecureStorage get flutterSecureStorage {
    return const FlutterSecureStorage();
  }

  @singleton
  CaddyCaPinningHttpClient get caddyCaPinningHttpClient =>
      _caddyCaPinningHttpClient ??= CaddyCaPinningHttpClient();

  @singleton
  CaddyCaPinStore get caddyCaPinStore =>
      _caddyCaPinStore ??= CaddyCaPinStore(const FlutterSecureStorage());

  @lazySingleton
  PocketCoderApiClient pocketCoderApiClient(
    PocketBase pocketBase,
    CaddyCaPinningHttpClient caddyCaPinningHttpClient,
  ) =>
      PocketCoderApiClient.fromPocketBase(pocketBase, caddyCaPinningHttpClient);

  /// HTTP client for API requests
  @lazySingleton
  http.Client get httpClient => AuthAwareHttpClient(
        _authHttpState,
        inner: caddyCaPinningHttpClient,
      );

  /// Base URL of the shared OAuth relay. No trailing slash.
  @Named('oauthRelayBaseUrl')
  @lazySingleton
  String get oauthRelayBaseUrl => 'https://oauth.relay.pocketcoder.org';

  @Named('releaseBaseUrl')
  @lazySingleton
  String get releaseBaseUrl => 'https://images.relay.pocketcoder.org/v1';

  /// Dev/debug-only: request the `-testing` variant of whatever release
  /// channel would otherwise be fetched, so a `staging`-branch build can be
  /// tested on a real device without ever touching `main` or the real
  /// `stable`/`nightly` channels. See ReleaseContentService.resolve's doc
  /// comment for the second, independent guard (kReleaseMode) that keeps
  /// this inert in a real release build even if this were ever set there.
  @Named('useTestingChannel')
  @lazySingleton
  bool get useTestingChannel =>
      const bool.fromEnvironment('USE_TESTING_CHANNEL');

  /// Dev/debug-only: which release channel to resolve when a caller doesn't
  /// pin one explicitly. Defaults to 'stable' -- forgetting to set this
  /// dart-define must always fall back to the real channel, never a
  /// testing one. See ReleaseContentService.resolve's kReleaseMode guard,
  /// which forces 'stable' regardless of this value in a real release build.
  @Named('releaseChannel')
  @lazySingleton
  String get releaseChannel =>
      const String.fromEnvironment('RELEASE_CHANNEL', defaultValue: 'stable');

  /// Local-only storage for the on-device error inbox. Never synced or
  /// transmitted — see docs/superpowers/specs/2026-08-02-error-catcher-inbox-design.md.
  @lazySingleton
  ErrorBoxStorage get errorBoxStorage => SharedPrefsErrorBoxStorage();
}
