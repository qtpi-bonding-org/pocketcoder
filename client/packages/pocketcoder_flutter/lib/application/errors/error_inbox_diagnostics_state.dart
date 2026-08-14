import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'error_inbox_diagnostics_state.freezed.dart';

@freezed
sealed class ErrorInboxDiagnosticsState
    with _$ErrorInboxDiagnosticsState, UiFlowStateMixin {
  const ErrorInboxDiagnosticsState._();

  const factory ErrorInboxDiagnosticsState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
  }) = _ErrorInboxDiagnosticsState;
}
