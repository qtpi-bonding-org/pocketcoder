import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/schedule_owner.dart';

part 'scheduler_state.freezed.dart';

@freezed
sealed class SchedulerState with _$SchedulerState, UiFlowStateMixin {
  const SchedulerState._();

  const factory SchedulerState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<ScheduleOwner> schedules,
    Object? error,
  }) = _SchedulerState;
}
