import 'dart:async';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/permission_modes/i_permission_mode_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'permission_mode_rules_state.dart';

@injectable
class PermissionModeRulesCubit extends AppCubit<PermissionModeRulesState> {
  final IPermissionModeRepository _repository;
  StreamSubscription? _subscription;

  PermissionModeRulesCubit(this._repository)
      : super(const PermissionModeRulesState());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchRules(String modeId) {
    emit(state.copyWith(status: UiFlowStatus.loading));
    _subscription?.cancel();
    _subscription = _repository.watchRules(modeId).listen(
      (rules) {
        emit(state.copyWith(
          status: UiFlowStatus.success,
          error: null,
          rules: rules,
        ));
      },
      onError: (e) {
        unawaited(pocketCoderDiagnosticCapture.capture(
            error: e,
            source: 'PermissionModeRulesCubit',
            operation: 'watchRules'));
        logError('PermissionModeRules: Failed to watch rules', e);
        emit(state.copyWith(error: e, status: UiFlowStatus.failure));
      },
    );
  }

  Future<void> createRule({
    required String modeId,
    required String tool,
    required String action,
  }) async {
    await tryOperation(() async {
      await _repository.createRule(modeId: modeId, tool: tool, action: action);
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
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
}
