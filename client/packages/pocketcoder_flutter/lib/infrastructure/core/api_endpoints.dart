/// Paths for transports intentionally outside the generated Dio client.
///
/// Generated operations own every ordinary request. These paths remain
/// handwritten because SSE, NDJSON, and the opaque SQLPage proxy require
/// incremental or content-type-transparent handling.
abstract final class StreamingEndpoints {
  static const String _root = '/api/pocketcoder/v1';

  static String agentStream(String chatId) => '$_root/chats/$chatId/stream';
  static const String ollamaPull = '$_root/ollama/pull';
  static String logs(String containerName) => '$_root/logs/$containerName';
  static const String observability = '$_root/proxy/observability/';
  static const String memory = '$_root/proxy/observability/memory.sql';
}
