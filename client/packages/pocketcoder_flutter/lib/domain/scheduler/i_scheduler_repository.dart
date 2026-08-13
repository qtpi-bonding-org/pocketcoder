import 'package:pocketcoder_flutter/domain/models/schedule_owner.dart';

abstract class ISchedulerRepository {
  Future<List<ScheduleOwner>> listSchedules();
  Future<ScheduleOwner> createSchedule({
    required String displayName,
    required String cron,
    required String prompt,
  });
  Future<void> renameSchedule(
      {required String id, required String displayName});
  Future<ScheduleOwner> updateCron({required String id, required String cron});
  Future<void> pauseSchedule(String id);
  Future<void> unpauseSchedule(String id);
  Future<void> deleteSchedule(String id);
  Future<void> runNow(String id);
}
