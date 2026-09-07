import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'permission_mode_rules_state.freezed.dart';

@freezed
sealed class PermissionModeRulesState
    with _$PermissionModeRulesState, UiFlowStateMixin {
  const PermissionModeRulesState._();

  const factory PermissionModeRulesState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<ToolPermission> rules,
    Object? error,
  }) = _PermissionModeRulesState;
}
