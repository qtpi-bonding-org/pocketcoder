import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'notification_rule_state.freezed.dart';

@freezed
sealed class NotificationRuleState with _$NotificationRuleState
    implements IUiFlowState {
  const NotificationRuleState._();

  const factory NotificationRuleState.initial() = _Initial;
  const factory NotificationRuleState.loading() = _Loading;
  const factory NotificationRuleState.loaded(Map<String, bool> rules) = _Loaded;
  const factory NotificationRuleState.error(String message) = _Error;

  @override
  UiFlowStatus get status => when(
        initial: () => UiFlowStatus.idle,
        loading: () => UiFlowStatus.loading,
        loaded: (_) => UiFlowStatus.success,
        error: (_) => UiFlowStatus.failure,
      );

  @override
  Object? get error => maybeWhen(
        error: (msg) => msg,
        orElse: () => null,
      );

  @override
  bool get isIdle => status == UiFlowStatus.idle;
  @override
  bool get isLoading => status == UiFlowStatus.loading;
  @override
  bool get isSuccess => status == UiFlowStatus.success;
  @override
  bool get isFailure => status == UiFlowStatus.failure;
  @override
  bool get hasError => error != null;
}
