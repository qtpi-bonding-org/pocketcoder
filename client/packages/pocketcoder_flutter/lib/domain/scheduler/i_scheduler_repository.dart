import 'package:pocketcoder_flutter/domain/models/schedule.dart';

abstract class ISchedulerRepository {
  Future<List<Schedule>> listSchedules();
  Future<Schedule> createSchedule({
    required String displayName,
    required String cron,
    required String prompt,
  });
  Future<void> renameSchedule({required String id, required String displayName});
  Future<Schedule> updateCron({required String id, required String cron});
  Future<void> pauseSchedule(String id);
  Future<void> unpauseSchedule(String id);
  Future<void> deleteSchedule(String id);
  Future<void> runNow(String id);
}
