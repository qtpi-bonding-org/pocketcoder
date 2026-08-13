// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_owner.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ScheduleOwner _$ScheduleOwnerFromJson(Map<String, dynamic> json) =>
    _ScheduleOwner(
      id: json['id'] as String,
      user: json['user'] as String,
      displayName: json['display_name'] as String,
      cron: json['cron'] as String?,
      prompt: json['prompt'] as String?,
      paused: json['paused'] as bool?,
      lastRun: json['last_run'] as String?,
    );

Map<String, dynamic> _$ScheduleOwnerToJson(_ScheduleOwner instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'display_name': instance.displayName,
      'cron': instance.cron,
      'prompt': instance.prompt,
      'paused': instance.paused,
      'last_run': instance.lastRun,
    };
