import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'tool_permissions_state.freezed.dart';

@freezed
sealed class ToolPermissionsState with _$ToolPermissionsState
    implements IUiFlowState {
  const ToolPermissionsState._();

  const factory ToolPermissionsState.initial() = _Initial;
  const factory ToolPermissionsState.loading() = _Loading;
  const factory ToolPermissionsState.loaded(List<ToolPermission> rules) =
      _Loaded;
  const factory ToolPermissionsState.error(String message) = _Error;

  @override
  UiFlowStatus get status => when(
        initial: () => UiFlowStatus.idle,
        loading: () => UiFlowStatus.loading,
        loaded: (_) => UiFlowStatus.success,
        error: (_) => UiFlowStatus.failure,
      );

  @override
  Object? get error => maybeWhen(
        error: (msg) => msg,
        orElse: () => null,
      );

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
