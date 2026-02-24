import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'terminal_state.freezed.dart';

@freezed
class SshTerminalState with _$SshTerminalState implements IUiFlowState {
  const SshTerminalState._();

  const factory SshTerminalState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    String? sessionId,
    @Default(false) bool isSyncingKeys,
  }) = _SshTerminalState;

  factory SshTerminalState.initial() => const SshTerminalState();

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

  bool get isConnecting => status == UiFlowStatus.loading;
  bool get isConnected => status == UiFlowStatus.success;
}
