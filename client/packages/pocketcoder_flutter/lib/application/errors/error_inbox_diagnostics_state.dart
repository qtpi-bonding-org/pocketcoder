import 'package:cubit_ui_flow/cubit_ui_flow.dart';

class ErrorInboxDiagnosticsState implements IUiFlowState {
  const ErrorInboxDiagnosticsState({
    this.status = UiFlowStatus.idle,
    this.error,
  });

  @override
  final UiFlowStatus status;
  @override
  final Object? error;

  ErrorInboxDiagnosticsState copyWith({
    UiFlowStatus? status,
    Object? error,
  }) {
    return ErrorInboxDiagnosticsState(
      status: status ?? this.status,
      error: error,
    );
  }

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
