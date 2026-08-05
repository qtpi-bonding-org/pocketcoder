import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_oauth_service.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_repository.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'mcp_state.dart';

/// A completed-but-undelivered OAuth grant, kept in memory only until
/// retryOAuthDelivery succeeds — see the spec's Component 2 failure-mode
/// list: "keep the token in memory long enough to offer a one-tap retry
/// without re-running the whole browser flow."
typedef _PendingOAuthDelivery = ({
  String serverId,
  String serverName,
  String accessToken,
  String? refreshToken,
});

@injectable
class McpCubit extends Cubit<McpState> {
  final IMcpRepository _repository;
  final IMcpOAuthService _oauthService;
  StreamSubscription? _subscription;

  _PendingOAuthDelivery? _pendingOAuthDelivery;

  McpCubit(this._repository, this._oauthService)
      : super(const McpState.initial());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchServers() {
    emit(const McpState.loading());
    _subscription?.cancel();
    _subscription = _repository.watchServers().listen(
      (servers) {
        emit(McpState.loaded(servers));
      },
      onError: (e) {
        unawaited(pocketCoderDiagnosticCapture.capture(
            error: e, source: 'McpCubit', operation: 'watchServers'));
        logError('MCP: Failed to watch servers', e);
        emit(McpState.error(e.toString()));
      },
    );
  }

  Future<void> authorize(String id, {Map<String, dynamic>? config}) async {
    try {
      await _repository.authorizeServer(id, config: config);
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
          error: e, source: 'McpCubit', operation: 'authorize');
      logError('MCP: Failed to authorize server', e);
      emit(McpState.error(e.toString()));
    }
  }

  Future<void> deny(String id) async {
    try {
      await _repository.denyServer(id);
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
          error: e, source: 'McpCubit', operation: 'deny');
      logError('MCP: Failed to deny server', e);
      emit(McpState.error(e.toString()));
    }
  }

  Future<void> createServer({
    required String name,
    String? image,
    Map<String, dynamic>? config,
    String? oauthProvider,
    String? oauthTokenEnvVar,
  }) async {
    try {
      await _repository.createServer(
        name: name,
        image: image,
        config: config,
        oauthProvider: oauthProvider,
        oauthTokenEnvVar: oauthTokenEnvVar,
      );
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
          error: e, source: 'McpCubit', operation: 'createServer');
      logError('MCP: Failed to create server', e);
      emit(McpState.error(e.toString()));
    }
  }

  /// True once [serverId]'s OAuth grant was obtained but delivery to
  /// PocketBase failed after retries — the UI should offer a one-tap
  /// retry via [retryOAuthDelivery] instead of re-running [connectOAuth].
  bool hasPendingOAuthDelivery(String serverId) =>
      _pendingOAuthDelivery?.serverId == serverId;

  /// Thin passthrough to IMcpOAuthService.supportedProviders() (which
  /// caches in-memory after the first success) — exposed here so the UI
  /// layer never reaches into the oauth service directly, matching how
  /// this cubit already encapsulates _repository.
  Future<List<McpOAuthProvider>> supportedOAuthProviders() =>
      _oauthService.supportedProviders();

  Future<void> connectOAuth(McpServer server) async {
    final provider = server.oauthProvider;
    if (provider == null || provider.isEmpty) {
      logError('MCP: connectOAuth called for a non-OAuth server', server.id);
      return;
    }
    try {
      final tokenPair = await _oauthService.authenticate(provider);
      await _deliverWithRetry(
        serverId: server.id,
        serverName: server.name,
        accessToken: tokenPair.accessToken,
        refreshToken: tokenPair.refreshToken,
      );
    } on McpOAuthException catch (e) {
      if (e.isCancelled) return; // dismissable, not an error state
      await pocketCoderDiagnosticCapture.capture(
          error: e, source: 'McpCubit', operation: 'connectOAuth');
      logError('MCP: OAuth authenticate failed', e);
      emit(McpState.error(e.toString()));
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
          error: e, source: 'McpCubit', operation: 'connectOAuth');
      logError('MCP: OAuth authenticate failed', e);
      emit(McpState.error(e.toString()));
    }
  }

  Future<void> retryOAuthDelivery(String serverId) async {
    final pending = _pendingOAuthDelivery;
    if (pending == null || pending.serverId != serverId) return;
    await _deliverWithRetry(
      serverId: pending.serverId,
      serverName: pending.serverName,
      accessToken: pending.accessToken,
      refreshToken: pending.refreshToken,
    );
  }

  /// Retries deliverOAuthToken 3 times with 1s/2s/4s backoff before giving
  /// up. On final failure the grant is cached in [_pendingOAuthDelivery] so
  /// a later retryOAuthDelivery call can resume without re-running
  /// connectOAuth's browser step.
  Future<void> _deliverWithRetry({
    required String serverId,
    required String serverName,
    required String accessToken,
    String? refreshToken,
  }) async {
    const delays = [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4)
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
          logError('MCP: OAuth token delivery failed after retries', e);
          await pocketCoderDiagnosticCapture.capture(
            error: e,
            source: 'McpCubit',
            operation: 'deliverOAuthToken',
          );
          emit(McpState.error(e.toString()));
          return;
        }
        await Future.delayed(delays[attempt]);
      }
    }
  }
}
