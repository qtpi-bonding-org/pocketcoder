import 'package:dio/dio.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart' as generated;

/// Shared transport boundary for generated PocketCoder operation APIs.
///
/// Collection CRUD remains on [PocketBase]. This adapter owns only deployment
/// URL, the raw PocketBase token, and generated operation clients.
class PocketCoderApiClient {
  PocketCoderApiClient({required Dio dio})
      : _dio = dio,
        release = generated.ReleaseApi(dio, generated.serializers),
        agent = generated.AgentApi(dio, generated.serializers),
        files = generated.FilesApi(dio, generated.serializers),
        harnessAuth = generated.HarnessAuthApi(dio, generated.serializers),
        logs = generated.LogsApi(dio, generated.serializers),
        mcp = generated.McpApi(dio, generated.serializers),
        observability = generated.ObservabilityApi(dio, generated.serializers),
        ollama = generated.OllamaApi(dio, generated.serializers),
        push = generated.PushApi(dio, generated.serializers),
        schedules = generated.SchedulesApi(dio, generated.serializers);

  factory PocketCoderApiClient.fromPocketBase(PocketBase pocketBase) {
    final dio = Dio(BaseOptions(baseUrl: pocketBase.baseURL));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
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
}
