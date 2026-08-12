// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Schedule _$ScheduleFromJson(Map<String, dynamic> json) => _Schedule(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      cron: json['cron'] as String,
      paused: json['paused'] as bool,
      currentlyRunning: json['currentlyRunning'] as bool,
      lastRun: json['lastRun'] as String?,
    );

Map<String, dynamic> _$ScheduleToJson(_Schedule instance) => <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'cron': instance.cron,
      'paused': instance.paused,
      'currentlyRunning': instance.currentlyRunning,
      'lastRun': instance.lastRun,
    };
