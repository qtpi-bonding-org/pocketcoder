import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart' as generated;
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';

import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_recovery.dart';

import 'auth_retry_interceptor.dart';
import 'ca_pin_retry_interceptor.dart';
import 'caddy_ca_pinning_http_client.dart';
import 'retry_interceptor.dart';

/// Shared transport boundary for generated PocketCoder operation APIs.
///
/// Collection CRUD remains on [PocketBase]. This adapter owns only deployment
/// URL, the raw PocketBase token, and generated operation clients.
class PocketCoderApiClient {
  PocketCoderApiClient({required Dio dio})
      : _dio = dio,
        release = generated.ReleaseApi(dio, generated.standardSerializers),
        agent = generated.AgentApi(dio, generated.standardSerializers),
        files = generated.FilesApi(dio, generated.standardSerializers),
        harnessAuth =
            generated.HarnessAuthApi(dio, generated.standardSerializers),
        liveActivities =
            generated.LiveActivitiesApi(dio, generated.standardSerializers),
        logs = generated.LogsApi(dio, generated.standardSerializers),
        mcp = generated.McpApi(dio, generated.standardSerializers),
        observability =
            generated.ObservabilityApi(dio, generated.standardSerializers),
        ollama = generated.OllamaApi(dio, generated.standardSerializers),
        push = generated.PushApi(dio, generated.standardSerializers),
        schedules = generated.SchedulesApi(dio, generated.standardSerializers);

  /// [caddyCaPinningHttpClient] is this app's single source of truth for
  /// deployment TLS trust (see its class doc) -- this Dio instance's
  /// transport is derived from it, and rebuilt whenever the pin changes,
  /// specifically so this client can never again drift into having its
  /// own independent, un-pinned trust the way it used to (a bare `Dio()`
  /// with Dio's own default `HttpClientAdapter`, which could never
  /// validate a deployment's self-signed CA regardless of what was
  /// pinned elsewhere in the app).
  factory PocketCoderApiClient.fromPocketBase(
    PocketBase pocketBase,
    CaddyCaPinningHttpClient caddyCaPinningHttpClient,
  ) {
    final dio = Dio(BaseOptions(baseUrl: pocketBase.baseURL));
    void applyCurrentTrust() {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: caddyCaPinningHttpClient.createHttpClient,
      );
    }

    applyCurrentTrust();
    caddyCaPinningHttpClient.onPinChanged.listen((_) => applyCurrentTrust());

    final authRetryInterceptor = AuthRetryInterceptor(dio);
    final caPinRetryInterceptor = CaPinRetryInterceptor(dio);
    dio.interceptors.add(SafeGetRetryInterceptor(dio));
    dio.interceptors.add(authRetryInterceptor);
    dio.interceptors.add(caPinRetryInterceptor);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // The deployment URL can change during onboarding. Resolve it from
          // PocketBase for every operation so generated clients cannot retain
          // a stale host.
          options.baseUrl = pocketBase.baseURL;
          final token = pocketBase.authStore.token;
          if (token.isNotEmpty) {
            // PocketBase uses the raw token, not `Bearer <token>`.
            options.headers['Authorization'] = token;
          }
          handler.next(options);
        },
      ),
    );
    final client = PocketCoderApiClient(dio: dio);
    client._authRetryInterceptor = authRetryInterceptor;
    client._caPinRetryInterceptor = caPinRetryInterceptor;
    return client;
  }

  final Dio _dio;
  AuthRetryInterceptor? _authRetryInterceptor;
  CaPinRetryInterceptor? _caPinRetryInterceptor;
  final generated.ReleaseApi release;
  final generated.AgentApi agent;
  final generated.FilesApi files;
  final generated.HarnessAuthApi harnessAuth;
  final generated.LiveActivitiesApi liveActivities;
  final generated.LogsApi logs;
  final generated.McpApi mcp;
  final generated.ObservabilityApi observability;
  final generated.OllamaApi ollama;
  final generated.PushApi push;
  final generated.SchedulesApi schedules;

  Dio get dio => _dio;

  /// Wires transport recovery after the shared DI graph has been created.
  void setAuthSessionCoordinator(AuthSessionCoordinator coordinator) {
    _authRetryInterceptor?.setRefreshCallback(coordinator.refresh);
  }

  /// Wires CA-pin recovery after the shared DI graph has been created --
  /// see CaPinRetryInterceptor.attachRecovery for why this can't happen at
  /// construction time.
  void attachCaPinRecovery(CaPinRecovery recovery) {
    _caPinRetryInterceptor?.attachRecovery(recovery);
  }

  static BuiltMap<String, JsonObject> encodeJson(
    Map<String, dynamic> value,
  ) {
    return BuiltMap<String, JsonObject>(
      value.map((key, item) => MapEntry(key, JsonObject(item))),
    );
  }

  static Map<String, dynamic> decodeJson(
    BuiltMap<String, JsonObject>? value,
  ) {
    if (value == null) return const {};
    return {
      for (final entry in value.entries) entry.key: entry.value.value,
    };
  }
}
