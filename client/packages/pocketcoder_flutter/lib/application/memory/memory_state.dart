import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/memory/i_memory_repository.dart';

part 'memory_state.freezed.dart';

@freezed
sealed class MemoryState with _$MemoryState, UiFlowStateMixin {
  const MemoryState._();

  const factory MemoryState({
    MemoryStats? stats,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
  }) = _MemoryState;
}
