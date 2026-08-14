import 'package:cubit_ui_flow/cubit_ui_flow.dart';

class ErrorInboxDiagnosticsState with UiFlowStateMixin {
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
}
