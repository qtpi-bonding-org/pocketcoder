import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'status_state.freezed.dart';

@freezed
sealed class StatusState with _$StatusState, UiFlowStateMixin {
  const StatusState._();

  const factory StatusState({
    @Default(true) bool isConnected,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
  }) = _StatusState;

  factory StatusState.initial() => const StatusState();
}
