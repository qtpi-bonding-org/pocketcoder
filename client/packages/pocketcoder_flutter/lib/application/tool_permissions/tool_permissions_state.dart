import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'tool_permissions_state.freezed.dart';

@freezed
sealed class ToolPermissionsState with _$ToolPermissionsState, UiFlowStateMixin {
  const ToolPermissionsState._();

  const factory ToolPermissionsState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<ToolPermission> rules,
    Object? error,
  }) = _ToolPermissionsState;
}
