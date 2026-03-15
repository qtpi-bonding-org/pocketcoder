part of 'tool_permissions_cubit.dart';

@freezed
class ToolPermissionsState with _$ToolPermissionsState implements IUiFlowState {
  const ToolPermissionsState._();

  const factory ToolPermissionsState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<ToolPermission> toolPermissions,
    Object? error,
  }) = _ToolPermissionsState;

  factory ToolPermissionsState.initial() => const ToolPermissionsState();

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
