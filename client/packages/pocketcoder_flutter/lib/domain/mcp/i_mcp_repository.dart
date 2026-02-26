import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';

abstract class IMcpRepository {
  Stream<List<McpServer>> watchServers();
  Future<void> authorizeServer(String id, {Map<String, dynamic>? config});
  Future<void> denyServer(String id);
}
