import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/schedule_owner.dart';

part 'scheduler_state.freezed.dart';

@freezed
sealed class SchedulerState with _$SchedulerState implements IUiFlowState {
  const SchedulerState._();

  const factory SchedulerState.initial() = _Initial;
  const factory SchedulerState.loading() = _Loading;
  const factory SchedulerState.loaded(List<ScheduleOwner> schedules) = _Loaded;
  const factory SchedulerState.error(String message) = _Error;

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
