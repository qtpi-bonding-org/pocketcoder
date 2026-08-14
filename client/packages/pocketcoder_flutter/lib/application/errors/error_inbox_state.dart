import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';

part 'error_inbox_state.freezed.dart';

@freezed
sealed class ErrorInboxState with _$ErrorInboxState, UiFlowStateMixin {
  const ErrorInboxState._();

  const factory ErrorInboxState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<ErrorBoxEntry> errors,
    Object? error,
  }) = _ErrorInboxState;
}
