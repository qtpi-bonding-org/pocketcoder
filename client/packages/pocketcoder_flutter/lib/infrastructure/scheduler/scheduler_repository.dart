import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/scheduler/i_scheduler_repository.dart';
import 'package:pocketcoder_flutter/domain/models/schedule.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';

@LazySingleton(as: ISchedulerRepository)
class SchedulerRepository implements ISchedulerRepository {
  final PocketBase _pb;

  SchedulerRepository(this._pb);

  @override
  Future<List<Schedule>> listSchedules() async {
    return tryMethod(
      () async {
        final response = await _pb.send<dynamic>(
          ApiEndpoints.schedulesList,
          method: 'POST',
          body: {},
        );
        final schedules = (response as Map<String, dynamic>)['schedules'] as List;
        return schedules
            .map((s) => Schedule.fromJson(s as Map<String, dynamic>))
            .toList();
      },
      SchedulerException.new,
      'listSchedules',
    );
  }

  @override
  Future<Schedule> createSchedule({
    required String displayName,
    required String cron,
    required String prompt,
  }) async {
    return tryMethod(
      () async {
        final response = await _pb.send<dynamic>(
          ApiEndpoints.schedulesCreate,
          method: 'POST',
          body: {'displayName': displayName, 'cron': cron, 'prompt': prompt},
        );
        return Schedule.fromJson(response as Map<String, dynamic>);
      },
      SchedulerException.new,
      'createSchedule',
    );
  }

  @override
  Future<void> renameSchedule({required String id, required String displayName}) async {
    return tryMethod(
      () async {
        await _pb.send<dynamic>(
          ApiEndpoints.schedulesRename,
          method: 'POST',
          body: {'id': id, 'displayName': displayName},
        );
      },
      SchedulerException.new,
      'renameSchedule',
    );
  }

  @override
  Future<Schedule> updateCron({required String id, required String cron}) async {
    return tryMethod(
      () async {
        final response = await _pb.send<dynamic>(
          ApiEndpoints.schedulesUpdateCron,
          method: 'POST',
          body: {'id': id, 'cron': cron},
        );
        return Schedule.fromJson(response as Map<String, dynamic>);
      },
      SchedulerException.new,
      'updateCron',
    );
  }

  @override
  Future<void> pauseSchedule(String id) async {
    return tryMethod(
      () async {
        await _pb.send<dynamic>(
          ApiEndpoints.schedulesPause,
          method: 'POST',
          body: {'id': id},
        );
      },
      SchedulerException.new,
      'pauseSchedule',
    );
  }

  @override
  Future<void> unpauseSchedule(String id) async {
    return tryMethod(
      () async {
        await _pb.send<dynamic>(
          ApiEndpoints.schedulesUnpause,
          method: 'POST',
          body: {'id': id},
        );
      },
      SchedulerException.new,
      'unpauseSchedule',
    );
  }

  @override
  Future<void> deleteSchedule(String id) async {
    return tryMethod(
      () async {
        await _pb.send<dynamic>(
          ApiEndpoints.schedulesDelete,
          method: 'POST',
          body: {'id': id},
        );
      },
      SchedulerException.new,
      'deleteSchedule',
    );
  }

  @override
  Future<void> runNow(String id) async {
    return tryMethod(
      () async {
        await _pb.send<dynamic>(
          ApiEndpoints.schedulesRunNow,
          method: 'POST',
          body: {'id': id},
        );
      },
      SchedulerException.new,
      'runNow',
    );
  }
}
