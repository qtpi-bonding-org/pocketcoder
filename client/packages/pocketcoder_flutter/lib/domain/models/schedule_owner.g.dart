// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_owner.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ScheduleOwner _$ScheduleOwnerFromJson(Map<String, dynamic> json) =>
    _ScheduleOwner(
      id: json['id'] as String,
      user: json['user'] as String,
      gooseScheduleId: json['goose_schedule_id'] as String,
      displayName: json['display_name'] as String,
    );

Map<String, dynamic> _$ScheduleOwnerToJson(_ScheduleOwner instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'goose_schedule_id': instance.gooseScheduleId,
      'display_name': instance.displayName,
    };
