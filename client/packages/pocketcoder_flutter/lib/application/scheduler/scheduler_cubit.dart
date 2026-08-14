import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/scheduler/i_scheduler_repository.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

import 'scheduler_state.dart';

@injectable
class SchedulerCubit extends AppCubit<SchedulerState> {
  final ISchedulerRepository _repository;

  SchedulerCubit(this._repository) : super(const SchedulerState());

  Future<void> loadSchedules() async {
    await tryOperation(() async {
      final schedules = await _repository.listSchedules();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        schedules: schedules,
      );
    }, emitLoading: true);
  }

  Future<void> createSchedule({
    required String displayName,
    required String cron,
    required String prompt,
  }) async {
    await tryOperation(() async {
      await _repository.createSchedule(
        displayName: displayName,
        cron: cron,
        prompt: prompt,
      );
      final schedules = await _repository.listSchedules();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        schedules: schedules,
      );
    });
  }

  Future<void> renameSchedule({
    required String id,
    required String displayName,
  }) async {
    await tryOperation(() async {
      await _repository.renameSchedule(id: id, displayName: displayName);
      final schedules = await _repository.listSchedules();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        schedules: schedules,
      );
    });
  }

  Future<void> updateCron({required String id, required String cron}) async {
    await tryOperation(() async {
      await _repository.updateCron(id: id, cron: cron);
      final schedules = await _repository.listSchedules();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        schedules: schedules,
      );
    });
  }

  Future<void> pauseSchedule(String id) async {
    await tryOperation(() async {
      await _repository.pauseSchedule(id);
      final schedules = await _repository.listSchedules();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        schedules: schedules,
      );
    });
  }

  Future<void> unpauseSchedule(String id) async {
    await tryOperation(() async {
      await _repository.unpauseSchedule(id);
      final schedules = await _repository.listSchedules();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        schedules: schedules,
      );
    });
  }

  Future<void> deleteSchedule(String id) async {
    await tryOperation(() async {
      await _repository.deleteSchedule(id);
      final schedules = await _repository.listSchedules();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        schedules: schedules,
      );
    });
  }

  Future<void> runNow(String id) async {
    await tryOperation(() async {
      await _repository.runNow(id);
      final schedules = await _repository.listSchedules();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        schedules: schedules,
      );
    });
  }
}
