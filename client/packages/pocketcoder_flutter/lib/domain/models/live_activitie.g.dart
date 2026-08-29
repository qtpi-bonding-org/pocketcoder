// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_activitie.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveActivitie _$LiveActivitieFromJson(Map<String, dynamic> json) =>
    _LiveActivitie(
      id: json['id'] as String,
      device: json['device'] as String,
      chat: json['chat'] as String,
      user: json['user'] as String,
      platform: $enumDecode(_$LiveActivitiePlatformEnumMap, json['platform'],
          unknownValue: LiveActivitiePlatform.unknown),
      status: $enumDecode(_$LiveActivitieStatusEnumMap, json['status'],
          unknownValue: LiveActivitieStatus.unknown),
      activityPushToken: json['activity_push_token'] as String?,
      contentStateVersion: (json['content_state_version'] as num).toDouble(),
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      lastPushAt: json['last_push_at'] == null
          ? null
          : DateTime.parse(json['last_push_at'] as String),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at'] as String),
      lastError: json['last_error'] as String?,
    );

Map<String, dynamic> _$LiveActivitieToJson(_LiveActivitie instance) =>
    <String, dynamic>{
      'id': instance.id,
      'device': instance.device,
      'chat': instance.chat,
      'user': instance.user,
      'platform': _$LiveActivitiePlatformEnumMap[instance.platform]!,
      'status': _$LiveActivitieStatusEnumMap[instance.status]!,
      'activity_push_token': instance.activityPushToken,
      'content_state_version': instance.contentStateVersion,
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
      'expires_at': instance.expiresAt?.toIso8601String(),
      'last_push_at': instance.lastPushAt?.toIso8601String(),
      'ended_at': instance.endedAt?.toIso8601String(),
      'last_error': instance.lastError,
    };

const _$LiveActivitiePlatformEnumMap = {
  LiveActivitiePlatform.ios: 'ios',
  LiveActivitiePlatform.android: 'android',
  LiveActivitiePlatform.unknown: '__unknown__',
};

const _$LiveActivitieStatusEnumMap = {
  LiveActivitieStatus.active: 'active',
  LiveActivitieStatus.ended: 'ended',
  LiveActivitieStatus.expired: 'expired',
  LiveActivitieStatus.failed: 'failed',
  LiveActivitieStatus.unknown: '__unknown__',
};
