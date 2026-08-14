import 'dart:async';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/notifications/i_notification_rule_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'notification_rule_state.dart';

@injectable
class NotificationRuleCubit extends AppCubit<NotificationRuleState> {
  final INotificationRuleRepository _repository;
  StreamSubscription? _subscription;

  NotificationRuleCubit(this._repository)
      : super(const NotificationRuleState());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchRules() {
    emit(state.copyWith(status: UiFlowStatus.loading));
    _subscription?.cancel();
    _subscription = _repository.watchRules().listen(
      (rules) => emit(state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        rules: rules,
      )),
      onError: (e) {
        unawaited(pocketCoderDiagnosticCapture.capture(
          error: e,
          source: 'NotificationRuleCubit',
          operation: 'watchRules',
        ));
        logError('NotificationRules: Failed to watch rules', e);
        emit(state.copyWith(error: e, status: UiFlowStatus.failure));
      },
    );
  }

  Future<void> setTypeEnabled(String type, bool enabled) async {
    await tryOperation(() async {
      await _repository.setTypeEnabled(type, enabled);
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }
}
