import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'package:pocketcoder_flutter/domain/scheduler/i_scheduler_repository.dart';

import 'scheduler_state.dart';

@injectable
class SchedulerCubit extends Cubit<SchedulerState> {
  final ISchedulerRepository _repository;

  SchedulerCubit(this._repository) : super(const SchedulerState.initial());

  Future<void> loadSchedules() async {
    emit(const SchedulerState.loading());
    try {
      final schedules = await _repository.listSchedules();
      emit(SchedulerState.loaded(schedules));
    } catch (e) {
      logError('Scheduler: Failed to load schedules', e);
      emit(SchedulerState.error(e.toString()));
    }
  }

  Future<void> createSchedule({
    required String displayName,
    required String cron,
    required String prompt,
  }) async {
    try {
      await _repository.createSchedule(displayName: displayName, cron: cron, prompt: prompt);
      await loadSchedules();
    } catch (e) {
      logError('Scheduler: Failed to create schedule', e);
      emit(SchedulerState.error(e.toString()));
    }
  }

  Future<void> renameSchedule({required String id, required String displayName}) async {
    try {
      await _repository.renameSchedule(id: id, displayName: displayName);
      await loadSchedules();
    } catch (e) {
      logError('Scheduler: Failed to rename schedule', e);
      emit(SchedulerState.error(e.toString()));
    }
  }

  Future<void> updateCron({required String id, required String cron}) async {
    try {
      await _repository.updateCron(id: id, cron: cron);
      await loadSchedules();
    } catch (e) {
      logError('Scheduler: Failed to update schedule cron', e);
      emit(SchedulerState.error(e.toString()));
    }
  }

  Future<void> pauseSchedule(String id) async {
    try {
      await _repository.pauseSchedule(id);
      await loadSchedules();
    } catch (e) {
      logError('Scheduler: Failed to pause schedule', e);
      emit(SchedulerState.error(e.toString()));
    }
  }

  Future<void> unpauseSchedule(String id) async {
    try {
      await _repository.unpauseSchedule(id);
      await loadSchedules();
    } catch (e) {
      logError('Scheduler: Failed to unpause schedule', e);
      emit(SchedulerState.error(e.toString()));
    }
  }

  Future<void> deleteSchedule(String id) async {
    try {
      await _repository.deleteSchedule(id);
      await loadSchedules();
    } catch (e) {
      logError('Scheduler: Failed to delete schedule', e);
      emit(SchedulerState.error(e.toString()));
    }
  }

  Future<void> runNow(String id) async {
    try {
      await _repository.runNow(id);
      await loadSchedules();
    } catch (e) {
      logError('Scheduler: Failed to run schedule now', e);
      emit(SchedulerState.error(e.toString()));
    }
  }
}
