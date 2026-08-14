import 'dart:async';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/tool_permissions/i_tool_permission_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'tool_permissions_state.dart';

@injectable
class ToolPermissionsCubit extends AppCubit<ToolPermissionsState> {
  final IToolPermissionRepository _repository;
  StreamSubscription? _subscription;

  ToolPermissionsCubit(this._repository) : super(const ToolPermissionsState());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchRules() {
    emit(state.copyWith(status: UiFlowStatus.loading));
    _subscription?.cancel();
    _subscription = _repository.watchRules().listen(
      (rules) {
        emit(state.copyWith(
          status: UiFlowStatus.success,
          error: null,
          rules: rules,
        ));
      },
      onError: (e) {
        unawaited(pocketCoderDiagnosticCapture.capture(
            error: e, source: 'ToolPermissionsCubit', operation: 'watchRules'));
        logError('ToolPermissions: Failed to watch rules', e);
        emit(state.copyWith(error: e, status: UiFlowStatus.failure));
      },
    );
  }

  Future<void> updateAction(String id, String action) async {
    await tryOperation(() async {
      await _repository.updateAction(id, action);
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }

  Future<void> setActive(String id, bool active) async {
    await tryOperation(() async {
      await _repository.setActive(id, active);
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }

  Future<void> createRule(
      {required String tool, required String action}) async {
    await tryOperation(() async {
      await _repository.createRule(tool: tool, action: action);
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }
}
