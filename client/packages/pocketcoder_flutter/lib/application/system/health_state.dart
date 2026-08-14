import 'package:freezed_annotation/freezed_annotation.dart';
import "package:pocketcoder_flutter/domain/models/healthcheck.dart";
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'health_state.freezed.dart';

@freezed
sealed class HealthState with _$HealthState, UiFlowStateMixin {
  const HealthState._();

  const factory HealthState({
    @Default([]) List<Healthcheck> checks,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
  }) = _HealthState;
}
