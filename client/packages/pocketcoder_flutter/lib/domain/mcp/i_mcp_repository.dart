import 'mcp_server.dart';

abstract class IMcpRepository {
  Stream<List<McpServer>> watchServers();
  Future<void> authorizeServer(String id);
  Future<void> denyServer(String id);
}
