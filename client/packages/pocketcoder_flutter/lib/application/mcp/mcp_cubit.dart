import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_repository.dart';
import "package:flutter_aeroform/infrastructure/core/logger.dart";
import 'mcp_state.dart';

@injectable
class McpCubit extends Cubit<McpState> {
  final IMcpRepository _repository;
  StreamSubscription? _subscription;

  McpCubit(this._repository) : super(const McpState.initial());

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
        logError('MCP: Failed to watch servers', e);
        emit(McpState.error(e.toString()));
      },
    );
  }

  Future<void> authorize(String id, {Map<String, dynamic>? config}) async {
    try {
      await _repository.authorizeServer(id, config: config);
    } catch (e) {
      logError('MCP: Failed to authorize server', e);
      emit(McpState.error(e.toString()));
    }
  }

  Future<void> deny(String id) async {
    try {
      await _repository.denyServer(id);
    } catch (e) {
      logError('MCP: Failed to deny server', e);
      emit(McpState.error(e.toString()));
    }
  }
}
