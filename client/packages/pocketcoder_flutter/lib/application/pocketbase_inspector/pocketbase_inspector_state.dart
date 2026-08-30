import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/pocketbase_inspector/i_pocketbase_inspector_repository.dart';

part 'pocketbase_inspector_state.freezed.dart';

@freezed
sealed class PocketbaseInspectorState
    with _$PocketbaseInspectorState, UiFlowStateMixin {
  const PocketbaseInspectorState._();

  const factory PocketbaseInspectorState({
    PocketbaseInspectorStats? stats,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
  }) = _PocketbaseInspectorState;
}
