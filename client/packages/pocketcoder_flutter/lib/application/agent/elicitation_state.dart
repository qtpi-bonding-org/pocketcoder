// State for ElicitationCubit (plan Task 12): the current
// SessionState.elicitation slice surfaced as a cubit state so the UI can
// render the requestedSchema form and submit the user's response.
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/agent/conversation.dart';

part 'elicitation_state.freezed.dart';

enum ElicitationOperation {
  open,
  submit,
}

@freezed
class ElicitationState with _$ElicitationState implements IUiFlowState {
  const ElicitationState._();

  const factory ElicitationState({
    String? chatId,
    @Default(SessionState.empty) SessionState sessionState,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    ElicitationOperation? lastOperation,
  }) = _ElicitationState;

  /// Convenience: the current elicitation map (null when no pending form).
  Map<String, dynamic>? get elicitation => sessionState.elicitation;

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