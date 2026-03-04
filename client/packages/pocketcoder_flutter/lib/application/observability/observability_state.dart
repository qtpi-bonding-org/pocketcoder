import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart';

part 'observability_state.freezed.dart';

@freezed
class ObservabilityState with _$ObservabilityState implements IUiFlowState {
  const ObservabilityState._();

  const factory ObservabilityState({
    SystemStats? stats,
    @Default([]) List<String> logs,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    String? currentContainer,
    Object? error,
  }) = _ObservabilityState;

  @override
  bool get isLoading => status == UiFlowStatus.loading;

  @override
  bool get isSuccess => status == UiFlowStatus.success;

  @override
  bool get isFailure => status == UiFlowStatus.failure;

  @override
  bool get isIdle => status == UiFlowStatus.idle;

  @override
  bool get hasError => error != null;
}
