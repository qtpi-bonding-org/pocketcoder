import 'package:injectable/injectable.dart';
import '../../domain/mcp/i_mcp_repository.dart';
import '../../domain/mcp/mcp_server.dart';
import '../../domain/exceptions.dart';
import '../../core/try_operation.dart';
import 'mcp_daos.dart';

@LazySingleton(as: IMcpRepository)
class McpRepository implements IMcpRepository {
  final McpServerDao _mcpServerDao;

  McpRepository(this._mcpServerDao);

  @override
  Stream<List<McpServer>> watchServers() {
    return _mcpServerDao.watch(sort: '-created');
  }

  @override
  Future<void> authorizeServer(String id) async {
    return tryMethod(
      () async {
        await _mcpServerDao.save(id, {
          'status': 'approved',
        });
      },
      McpException.new,
      'authorizeServer',
    );
  }

  @override
  Future<void> denyServer(String id) async {
    return tryMethod(
      () async {
        await _mcpServerDao.save(id, {
          'status': 'denied',
        });
      },
      McpException.new,
      'denyServer',
    );
  }
}
