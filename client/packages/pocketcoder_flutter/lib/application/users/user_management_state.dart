import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/auth/user.dart';

part 'user_management_state.freezed.dart';

@freezed
sealed class UserManagementState
    with _$UserManagementState, UiFlowStateMixin {
  const UserManagementState._();

  const factory UserManagementState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<User> users,
    Object? error,
  }) = _UserManagementState;
}
