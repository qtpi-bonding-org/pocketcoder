import 'package:freezed_annotation/freezed_annotation.dart';
import "package:flutter_aeroform/domain/models/healthcheck.dart";
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'health_state.freezed.dart';

@freezed
class HealthState with _$HealthState implements IUiFlowState {
  const HealthState._();

  const factory HealthState({
    @Default([]) List<Healthcheck> checks,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
  }) = _HealthState;

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
