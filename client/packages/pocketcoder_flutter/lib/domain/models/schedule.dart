import 'package:freezed_annotation/freezed_annotation.dart';

part 'schedule.freezed.dart';
part 'schedule.g.dart';

/// A Goose scheduled recipe run, merged with its PocketBase ownership row
/// (schedule_owners). Unlike other domain models in this app, this is NOT
/// directly PocketBase-backed the usual way: `id` is schedule_owners'
/// PocketBase record id, but `cron`/`paused`/`currentlyRunning`/`lastRun`
/// come live from Goose on every request — there is no `fromRecord`. Every
/// instance is built from JSON returned by the scheduler API routes
/// (services/pocketbase/internal/api/schedules.go). See
/// docs/superpowers/specs/2026-07-23-scheduler-ui-design.md.
@freezed
abstract class Schedule with _$Schedule {
  const factory Schedule({
    required String id,
    @JsonKey(name: 'displayName') required String displayName,
    required String cron,
    required bool paused,
    @JsonKey(name: 'currentlyRunning') required bool currentlyRunning,
    @JsonKey(name: 'lastRun') String? lastRun,
  }) = _Schedule;

  factory Schedule.fromJson(Map<String, dynamic> json) =>
      _$ScheduleFromJson(json);
}
