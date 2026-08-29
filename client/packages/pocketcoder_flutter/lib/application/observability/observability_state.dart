import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart';

part 'observability_state.freezed.dart';

@freezed
sealed class ObservabilityState with _$ObservabilityState, UiFlowStateMixin {
  const ObservabilityState._();

  const factory ObservabilityState({
    SystemStats? stats,
    @Default([]) List<LogEntry> logs,
    @Default([]) List<ContainerInfo> containers,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    String? currentContainer,
    Object? error,
  }) = _ObservabilityState;
}
