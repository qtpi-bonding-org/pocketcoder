import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'notification_rule_state.freezed.dart';

@freezed
sealed class NotificationRuleState with _$NotificationRuleState, UiFlowStateMixin {
  const NotificationRuleState._();

  const factory NotificationRuleState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default({}) Map<String, bool> rules,
    Object? error,
  }) = _NotificationRuleState;
}
