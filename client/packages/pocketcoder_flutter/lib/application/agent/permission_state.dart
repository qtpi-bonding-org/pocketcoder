// State for PermissionCubit (plan Task 12): the current SessionState.permission
// slice surfaced as a cubit state so the UI can render the prompt and call
// authorize/deny. Pure data — no protocol types leak past this file.
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/agent/conversation.dart';

part 'permission_state.freezed.dart';

enum PermissionOperation {
  open,
  authorize,
  deny,
}

@freezed
sealed class PermissionState with _$PermissionState implements IUiFlowState {
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

  @override
  bool get isLoading => status == UiFlowStatus.loading;

  @override
  bool get isSuccess => status == UiFlowStatus.success;

  @override
  bool get isFailure => status == UiFlowStatus.failure;

  @override
  bool get isIdle => status == UiFlowStatus.idle;

  @override
  bool get hasError => error != null;
}