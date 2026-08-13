import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'schedule_owner.freezed.dart';
part 'schedule_owner.g.dart';

@freezed
abstract class ScheduleOwner with _$ScheduleOwner {
  const factory ScheduleOwner({
    required String id,
    required String user,
    required String displayName,
    String? cron,
    String? prompt,
    bool? paused,
    String? lastRun,
  }) = _ScheduleOwner;

  factory ScheduleOwner.fromRecord(RecordModel record) =>
      ScheduleOwner.fromJson(record.toJson());

  factory ScheduleOwner.fromJson(Map<String, dynamic> json) =>
      _$ScheduleOwnerFromJson(json);
}
