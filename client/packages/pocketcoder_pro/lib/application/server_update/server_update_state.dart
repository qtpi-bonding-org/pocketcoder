import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

import 'package:pocketcoder_pro/domain/server_update/server_update_result.dart';

part 'server_update_state.freezed.dart';

@freezed
sealed class ServerUpdateState with _$ServerUpdateState implements IUiFlowState {
  const ServerUpdateState._();

  const factory ServerUpdateState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    ServerUpdateResult? result,
  }) = _ServerUpdateState;

  factory ServerUpdateState.initial() => const ServerUpdateState();

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
