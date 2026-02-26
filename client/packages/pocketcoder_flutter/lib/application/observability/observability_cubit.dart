import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'observability_state.dart';

@injectable
class ObservabilityCubit extends Cubit<ObservabilityState> {
  final IObservabilityRepository _repository;
  StreamSubscription? _logSub;

  ObservabilityCubit(this._repository) : super(const ObservabilityState());

  @override
  Future<void> close() {
    _logSub?.cancel();
    return super.close();
  }

  Future<void> refreshStats() async {
    emit(state.copyWith(status: UiFlowStatus.loading));
    try {
      final stats = await _repository.fetchSystemStats();
      emit(state.copyWith(
        stats: stats,
        status: UiFlowStatus.success,
      ));
    } catch (e) {
      logError('📈 [ObservabilityCubit] Failed to refresh stats: $e');
      emit(state.copyWith(
        error: e,
        status: UiFlowStatus.failure,
      ));
    }
  }

  void startLogStreaming(String containerName) {
    logInfo('📈 [ObservabilityCubit] Starting log stream for $containerName');
    _logSub?.cancel();
    emit(state.copyWith(
      currentContainer: containerName,
      logs: [],
    ));

    _logSub = _repository.watchLogs(containerName).listen(
      (logLine) {
        // Keep only last 500 lines for performance
        final updatedLogs = List<String>.from(state.logs)..add(logLine);
        if (updatedLogs.length > 500) {
          updatedLogs.removeAt(0);
        }
        emit(state.copyWith(logs: updatedLogs));
      },
      onError: (e) {
        logError('📈 [ObservabilityCubit] Log stream error: $e');
        emit(state.copyWith(error: e, status: UiFlowStatus.failure));
      },
    );
  }

  void stopLogStreaming() {
    logInfo('📈 [ObservabilityCubit] Stopping log stream');
    _logSub?.cancel();
    _logSub = null;
    emit(state.copyWith(currentContainer: null));
  }
}
