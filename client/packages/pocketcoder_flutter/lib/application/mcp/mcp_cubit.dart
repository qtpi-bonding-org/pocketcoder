import 'dart:async';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_oauth_service.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_repository.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'mcp_state.dart';

typedef _PendingOAuthDelivery = ({
  String serverId,
  String serverName,
  String accessToken,
  String? refreshToken,
});

@injectable
class McpCubit extends AppCubit<McpState> {
  final IMcpRepository _repository;
  final IMcpOAuthService _oauthService;
  StreamSubscription? _subscription;

  _PendingOAuthDelivery? _pendingOAuthDelivery;

  McpCubit(this._repository, this._oauthService) : super(const McpState());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchServers() {
    emit(state.copyWith(status: UiFlowStatus.loading));
    _subscription?.cancel();
    _subscription = _repository.watchServers().listen(
      (servers) {
        emit(state.copyWith(
          status: UiFlowStatus.success,
          error: null,
          servers: servers,
        ));
      },
      onError: (e) {
        unawaited(pocketCoderDiagnosticCapture.capture(
            error: e, source: 'McpCubit', operation: 'watchServers'));
        logError('MCP: Failed to watch servers', e);
        emit(state.copyWith(error: e, status: UiFlowStatus.failure));
      },
    );
  }

  Future<void> authorize(String id, {Map<String, dynamic>? config}) async {
    await tryOperation(() async {
      await _repository.authorizeServer(id, config: config);
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }

  Future<void> deny(String id) async {
    await tryOperation(() async {
      await _repository.denyServer(id);
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }

  Future<void> createServer({
    required String name,
    String? image,
    Map<String, dynamic>? config,
    String? oauthProvider,
    String? oauthTokenEnvVar,
  }) async {
    await tryOperation(() async {
      await _repository.createServer(
        name: name,
        image: image,
        config: config,
        oauthProvider: oauthProvider,
        oauthTokenEnvVar: oauthTokenEnvVar,
      );
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }

  bool hasPendingOAuthDelivery(String serverId) =>
      _pendingOAuthDelivery?.serverId == serverId;

  Future<List<McpOAuthProvider>> supportedOAuthProviders() =>
      _oauthService.supportedProviders();

  Future<void> connectOAuth(McpServer server) async {
    final provider = server.oauthProvider;
    if (provider == null || provider.isEmpty) {
      logError('MCP: connectOAuth called for a non-OAuth server', server.id);
      return;
    }

    await tryOperation(() async {
      McpOAuthTokenPair tokenPair;
      try {
        tokenPair = await _oauthService.authenticate(provider);
      } on McpOAuthException catch (e) {
        if (e.isCancelled) return state;
        rethrow;
      }
      await _deliverWithRetry(
        serverId: server.id,
        serverName: server.name,
        accessToken: tokenPair.accessToken,
        refreshToken: tokenPair.refreshToken,
      );
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }

  Future<void> retryOAuthDelivery(String serverId) async {
    final pending = _pendingOAuthDelivery;
    if (pending == null || pending.serverId != serverId) return;
    await tryOperation(() async {
      await _deliverWithRetry(
        serverId: pending.serverId,
        serverName: pending.serverName,
        accessToken: pending.accessToken,
        refreshToken: pending.refreshToken,
      );
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }

  Future<void> _deliverWithRetry({
    required String serverId,
    required String serverName,
    required String accessToken,
    String? refreshToken,
  }) async {
    const delays = [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ];
    for (var attempt = 0; attempt <= delays.length; attempt++) {
      try {
        await _repository.deliverOAuthToken(
          serverName,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        _pendingOAuthDelivery = null;
        return;
      } catch (e) {
        if (attempt == delays.length) {
          _pendingOAuthDelivery = (
            serverId: serverId,
            serverName: serverName,
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
          rethrow;
        }
        await Future.delayed(delays[attempt]);
      }
    }
  }
}
