import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'permission_modes_state.freezed.dart';

@freezed
sealed class PermissionModesState
    with _$PermissionModesState, UiFlowStateMixin {
  const PermissionModesState._();

  const factory PermissionModesState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<PermissionMode> modes,
    Object? error,
  }) = _PermissionModesState;
}
