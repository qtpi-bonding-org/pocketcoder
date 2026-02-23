import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/mcp/mcp_server.dart';
import '../core/base_dao.dart';
import '../core/collections.dart';

@lazySingleton
class McpServerDao extends BaseDao<McpServer> {
  McpServerDao(PocketBase pb)
      : super(pb, Collections.mcpServers, McpServer.fromJson);
}
