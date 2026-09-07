import 'dart:async';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/permission_modes/i_permission_mode_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'permission_modes_state.dart';

@injectable
class PermissionModesCubit extends AppCubit<PermissionModesState> {
  final IPermissionModeRepository _repository;
  StreamSubscription? _subscription;

  PermissionModesCubit(this._repository) : super(const PermissionModesState());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchModes() {
    emit(state.copyWith(status: UiFlowStatus.loading));
    _subscription?.cancel();
    _subscription = _repository.watchModes().listen(
      (modes) {
        emit(state.copyWith(
          status: UiFlowStatus.success,
          error: null,
          modes: modes,
        ));
      },
      onError: (e) {
        unawaited(pocketCoderDiagnosticCapture.capture(
            error: e, source: 'PermissionModesCubit', operation: 'watchModes'));
        logError('PermissionModes: Failed to watch modes', e);
        emit(state.copyWith(error: e, status: UiFlowStatus.failure));
      },
    );
  }

  Future<void> duplicateMode({
    required PermissionMode source,
    required String newName,
  }) async {
    await tryOperation(() async {
      await _repository.duplicateMode(source: source, newName: newName);
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }

  Future<void> saveMode(PermissionMode mode) async {
    await tryOperation(() async {
      await _repository.saveMode(mode);
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }

  Future<void> deleteMode(String id) async {
    await tryOperation(() async {
      await _repository.deleteMode(id);
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }
}
