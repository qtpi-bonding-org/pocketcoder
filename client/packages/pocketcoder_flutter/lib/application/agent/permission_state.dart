import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';

part 'permission_state.freezed.dart';

enum PermissionOperation {
  open,
  authorize,
  deny,
}

@freezed
sealed class PermissionState with _$PermissionState, UiFlowStateMixin {
  const PermissionState._();

  const factory PermissionState({
    String? chatId,
    @Default(SessionState.empty) SessionState sessionState,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    PermissionOperation? lastOperation,
  }) = _PermissionState;

  /// Convenience: the current permission map (null when no pending request).
  Map<String, dynamic>? get permission => sessionState.permission;
}
