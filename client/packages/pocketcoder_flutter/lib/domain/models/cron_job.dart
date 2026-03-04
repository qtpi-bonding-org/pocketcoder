import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'cron_job.freezed.dart';
part 'cron_job.g.dart';

@freezed
class CronJob with _$CronJob {
  const factory CronJob({
    required String id,
    required String name,
    String? description,
    required String cronExpression,
    required String prompt,
    @JsonKey(unknownEnumValue: CronJobSessionMode.unknown) required CronJobSessionMode sessionMode,
    String? chat,
    String? agent,
    required String user,
    bool? enabled,
    DateTime? lastExecuted,
    String? lastStatus,
    String? lastError,
    DateTime? created,
    DateTime? updated,
  }) = _CronJob;

  factory CronJob.fromRecord(RecordModel record) =>
      CronJob.fromJson(record.toJson());

  factory CronJob.fromJson(Map<String, dynamic> json) =>
      _$CronJobFromJson(json);
}

enum CronJobSessionMode {
  @JsonValue('existing')
  existing,
  @JsonValue('new')
  v_new,
  @JsonValue('__unknown__')
  unknown,
}
