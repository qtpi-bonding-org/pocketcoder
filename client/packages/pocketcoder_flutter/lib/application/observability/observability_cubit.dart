import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'observability_state.dart';

@injectable
class ObservabilityCubit extends AppCubit<ObservabilityState> {
  final IObservabilityRepository _repository;
  StreamSubscription? _logSub;

  ObservabilityCubit(this._repository) : super(const ObservabilityState());

  @override
  Future<void> close() {
    _logSub?.cancel();
    return super.close();
  }

  Future<void> refreshStats() async {
    await tryOperation(() async {
      final stats = await _repository.fetchSystemStats();
      return state.copyWith(
        stats: stats,
        status: UiFlowStatus.success,
      );
    });
  }

  Future<void> loadContainers() async {
    await tryOperation(() async {
      final containers = await _repository.listContainers();
      return state.copyWith(
        containers: containers,
        status: UiFlowStatus.success,
      );
    });
  }

  void startLogStreaming(String containerName) {
    logInfo('📈 [ObservabilityCubit] Starting container log stream');
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
        logError('📈 [ObservabilityCubit] Log stream error', e);
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
