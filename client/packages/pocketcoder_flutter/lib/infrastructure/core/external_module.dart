import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'auth_store.dart';
import "package:flutter_aeroform/infrastructure/core/logger.dart";
import 'package:flutter_aeroform/domain/models/app_config.dart';
import 'auth_interceptor_client.dart';

@module
abstract class ExternalModule {
  @preResolve
  @singleton
  Future<PocketBase> get pocketBase async {
    logInfo('PocketBaseInit: Starting...');

    // Determine base URL based on environment
    const baseUrl =
        kDebugMode ? 'http://127.0.0.1:8090' : 'http://pocketbase:8090';
    logDebug('PocketBaseInit: Using URL: $baseUrl');

    // Load Schema (for offline capabilities)
    String? schemaJson;
    try {
      logDebug('PocketBaseInit: Loading assets/pb_schema.json...');
      // Use package path to be robust across multi-package builds (especially Web)
      schemaJson = await rootBundle
          .loadString('packages/pocketcoder_flutter/assets/pb_schema.json');
      logDebug('PocketBaseInit: Schema loaded (${schemaJson.length} chars)');
    } catch (e) {
      logWarning(
          'PocketBaseInit: ⚠️ Warning - failed to load schema asset (as package): $e');
      // Fallback to direct path for local runs
      try {
        schemaJson = await rootBundle.loadString('assets/pb_schema.json');
        logDebug('PocketBaseInit: Schema loaded via direct path');
      } catch (e2) {
        logWarning('PocketBaseInit: ⚠️ Fallback direct path also failed: $e2');
      }
    }

    // Create secure auth store with flutter_secure_storage
    const storage = FlutterSecureStorage();
    final authStoreConfig = AuthStoreConfig(storage);
    final authStore = authStoreConfig.createAuthStore();

    // Initialize PocketBase Drift Client with persistent auth
    final client = $PocketBase.database(
      baseUrl,
      requestPolicy: RequestPolicy.cacheAndNetwork,
      authStore: authStore,
      httpClientFactory: () => AuthInterceptorClient(http.Client(), storage),
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
  AuthStoreConfig get authStoreConfig {
    return AuthStoreConfig(const FlutterSecureStorage());
  }

  @singleton
  FlutterSecureStorage get flutterSecureStorage {
    return const FlutterSecureStorage();
  }

  /// App configuration for mobile deployment feature
  @singleton
  AppConfig get appConfig {
    return AppConfig(
      linodeClientId: AppConfig.kLinodeClientId,
      linodeRedirectUri: AppConfig.kLinodeRedirectUri,
      cloudInitTemplateUrl: AppConfig.kCloudInitTemplateUrl,
      maxPollingAttempts: AppConfig.kMaxPollingAttempts,
      initialPollingIntervalSeconds: AppConfig.kInitialPollingIntervalSeconds,
    );
  }

  /// Linode OAuth client ID for API clients
  @Named('linodeClientId')
  @singleton
  String get linodeClientId => AppConfig.kLinodeClientId;

  /// HTTP client for API requests
  @lazySingleton
  http.Client get httpClient => http.Client();
}
