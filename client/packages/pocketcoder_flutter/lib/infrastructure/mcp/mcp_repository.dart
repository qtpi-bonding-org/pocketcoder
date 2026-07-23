import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_repository.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
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
  Future<void> authorizeServer(String id,
      {Map<String, dynamic>? config}) async {
    return tryMethod(
      () async {
        await _mcpServerDao.save(id, {
          'status': 'approved',
          if (config != null) 'config': config,
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

  @override
  Future<void> createServer({
    required String name,
    String? image,
    Map<String, dynamic>? config,
  }) async {
    return tryMethod(
      () async {
        await _mcpServerDao.save(null, {
          'name': name,
          'status': 'approved',
          if (image != null && image.isNotEmpty) 'image': image,
          if (config != null) 'config': config,
        });
      },
      McpException.new,
      'createServer',
    );
  }
}
