import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import "package:flutter_aeroform/infrastructure/core/collections.dart";

@lazySingleton
class McpServerDao extends BaseDao<McpServer> {
  McpServerDao(PocketBase pb)
      : super(pb, Collections.mcpServers, McpServer.fromJson);
}
