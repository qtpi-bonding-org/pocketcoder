import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_repository.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_daos.dart';

@LazySingleton(as: IMcpRepository)
class McpRepository implements IMcpRepository {
  final McpServerDao _mcpServerDao;
  final PocketCoderApiClient _api;

  McpRepository(this._mcpServerDao, this._api);

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
    String? oauthProvider,
    String? oauthTokenEnvVar,
  }) async {
    return tryMethod(
      () async {
        await _mcpServerDao.save(null, {
          'name': name,
          'status': 'approved',
          if (image != null && image.isNotEmpty) 'image': image,
          if (config != null) 'config': config,
          if (oauthProvider != null && oauthProvider.isNotEmpty) 'oauth_provider': oauthProvider,
          if (oauthTokenEnvVar != null && oauthTokenEnvVar.isNotEmpty) 'oauth_token_env_var': oauthTokenEnvVar,
        });
      },
      McpException.new,
      'createServer',
    );
  }

  @override
  Future<void> deliverOAuthToken(
    String serverName, {
    required String accessToken,
    String? refreshToken,
  }) async {
    return tryMethod(
      () async {
        await _api.mcp.storeMcpOAuthToken(
          requestBody: PocketCoderApiClient.encodeJson({
            'server_name': serverName,
            'access_token': accessToken,
            if (refreshToken != null && refreshToken.isNotEmpty) 'refresh_token': refreshToken,
          }),
        );
      },
      McpException.new,
      'deliverOAuthToken',
    );
  }
}
