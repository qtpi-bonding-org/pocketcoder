import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:dio/dio.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart' as generated;

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
        logs = generated.LogsApi(dio, generated.standardSerializers),
        mcp = generated.McpApi(dio, generated.standardSerializers),
        observability =
            generated.ObservabilityApi(dio, generated.standardSerializers),
        ollama = generated.OllamaApi(dio, generated.standardSerializers),
        push = generated.PushApi(dio, generated.standardSerializers),
        schedules = generated.SchedulesApi(dio, generated.standardSerializers);

  factory PocketCoderApiClient.fromPocketBase(PocketBase pocketBase) {
    final dio = Dio(BaseOptions(baseUrl: pocketBase.baseURL));
    dio.interceptors.add(SafeGetRetryInterceptor(dio));
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
    return PocketCoderApiClient(dio: dio);
  }

  final Dio _dio;
  final generated.ReleaseApi release;
  final generated.AgentApi agent;
  final generated.FilesApi files;
  final generated.HarnessAuthApi harnessAuth;
  final generated.LogsApi logs;
  final generated.McpApi mcp;
  final generated.ObservabilityApi observability;
  final generated.OllamaApi ollama;
  final generated.PushApi push;
  final generated.SchedulesApi schedules;

  Dio get dio => _dio;

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
