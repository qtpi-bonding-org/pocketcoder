// State for SessionControlsCubit (plan Task 12): the current
// SessionState.modes + SessionState.config slices surfaced as a cubit state
// so the UI can render mode/config pickers and forward selections through
// AgentChatRepository.setMode / setConfigOption.
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';

part 'session_controls_state.freezed.dart';

enum SessionControlsOperation {
  open,
  selectMode,
  setOption,
}

@freezed
sealed class SessionControlsState with _$SessionControlsState
    , UiFlowStateMixin {
  const SessionControlsState._();

  const factory SessionControlsState({
    String? chatId,
    @Default(SessionState.empty) SessionState sessionState,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    SessionControlsOperation? lastOperation,
  }) = _SessionControlsState;

  /// Convenience: the current modes map (null when no modes published).
  Map<String, dynamic>? get modes => sessionState.modes;

  /// Convenience: the current config map (null when no config published).
  Map<String, dynamic>? get config => sessionState.config;
}