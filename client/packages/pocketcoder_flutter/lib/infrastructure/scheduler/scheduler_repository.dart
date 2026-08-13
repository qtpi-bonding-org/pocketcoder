import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/scheduler/i_scheduler_repository.dart';
import 'package:pocketcoder_flutter/domain/models/schedule_owner.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';
import 'package:pocketcoder_flutter/infrastructure/scheduler/schedule_owner_dao.dart';

@LazySingleton(as: ISchedulerRepository)
class SchedulerRepository implements ISchedulerRepository {
  final PocketBase _pb;
  final ScheduleOwnerDao _dao;

  SchedulerRepository(this._pb, this._dao);

  @override
  Future<List<ScheduleOwner>> listSchedules() async {
    return tryMethod(
      () async {
        return _dao.getFullList(sort: 'display_name');
      },
      SchedulerException.new,
      'listSchedules',
    );
  }

  @override
  Future<ScheduleOwner> createSchedule({
    required String displayName,
    required String cron,
    required String prompt,
  }) async {
    return tryMethod(
      () async {
        return _dao.save(
          null,
          {
            'display_name': displayName,
            'cron': cron,
            'prompt': prompt,
            'paused': false,
          },
        );
      },
      SchedulerException.new,
      'createSchedule',
    );
  }

  @override
  Future<void> renameSchedule(
      {required String id, required String displayName}) async {
    return tryMethod(
      () async {
        await _dao.save(id, {'display_name': displayName});
      },
      SchedulerException.new,
      'renameSchedule',
    );
  }

  @override
  Future<ScheduleOwner> updateCron(
      {required String id, required String cron}) async {
    return tryMethod(
      () async {
        return _dao.save(id, {'cron': cron});
      },
      SchedulerException.new,
      'updateCron',
    );
  }

  @override
  Future<void> pauseSchedule(String id) async {
    return tryMethod(
      () async {
        await _dao.save(id, {'paused': true});
      },
      SchedulerException.new,
      'pauseSchedule',
    );
  }

  @override
  Future<void> unpauseSchedule(String id) async {
    return tryMethod(
      () async {
        await _dao.save(id, {'paused': false});
      },
      SchedulerException.new,
      'unpauseSchedule',
    );
  }

  @override
  Future<void> deleteSchedule(String id) async {
    return tryMethod(
      () async {
        await _dao.delete(id);
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
