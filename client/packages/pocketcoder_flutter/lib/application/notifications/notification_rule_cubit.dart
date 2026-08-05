import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/notifications/i_notification_rule_repository.dart';
import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'notification_rule_state.dart';

@injectable
class NotificationRuleCubit extends Cubit<NotificationRuleState> {
  final INotificationRuleRepository _repository;
  StreamSubscription? _subscription;

  NotificationRuleCubit(this._repository)
      : super(const NotificationRuleState.initial());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchRules() {
    emit(const NotificationRuleState.loading());
    _subscription?.cancel();
    _subscription = _repository.watchRules().listen(
      (rules) => emit(NotificationRuleState.loaded(rules)),
      onError: (e) {
        unawaited(pocketCoderDiagnosticCapture.capture(
          error: e,
          source: 'NotificationRuleCubit',
          operation: 'watchRules',
        ));
        logError('NotificationRules: Failed to watch rules', e);
        emit(NotificationRuleState.error(e.toString()));
      },
    );
  }

  Future<void> setTypeEnabled(String type, bool enabled) async {
    try {
      await _repository.setTypeEnabled(type, enabled);
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
        error: e,
        source: 'NotificationRuleCubit',
        operation: 'setTypeEnabled',
      );
      logError('NotificationRules: Failed to update $type', e);
      emit(NotificationRuleState.error(e.toString()));
    }
  }
}
