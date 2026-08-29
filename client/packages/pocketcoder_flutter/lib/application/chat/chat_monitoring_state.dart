// State for ChatMonitoringCubit: mirrors SessionControlsState's shape --
// a flat, single-chat slice of the `chats` collection's own `monitored`
// field, watched live so an external flip (e.g. the archive-triggered
// auto-unmonitor server hook) is reflected without a manual refetch.
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'chat_monitoring_state.freezed.dart';

enum ChatMonitoringOperation {
  open,
  toggle,
}

@freezed
sealed class ChatMonitoringState with _$ChatMonitoringState, UiFlowStateMixin {
  const ChatMonitoringState._();

  const factory ChatMonitoringState({
    String? chatId,
    @Default(false) bool monitored,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    ChatMonitoringOperation? lastOperation,
  }) = _ChatMonitoringState;
}
