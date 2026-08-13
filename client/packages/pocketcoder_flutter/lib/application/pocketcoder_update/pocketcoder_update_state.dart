import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

import 'package:pocketcoder_flutter/domain/pocketcoder_update/pocketcoder_update_result.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';

part 'pocketcoder_update_state.freezed.dart';

@freezed
sealed class PocketCoderUpdateState
    with _$PocketCoderUpdateState
    implements IUiFlowState {
  const PocketCoderUpdateState._();

  const factory PocketCoderUpdateState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    ServerReleaseStatusSnapshot? preview,
    PocketCoderUpdateResult? result,
    @Default(false) bool upgradeConfirmed,
  }) = _PocketCoderUpdateState;

  factory PocketCoderUpdateState.initial() => const PocketCoderUpdateState();

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
