// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harness_auth_attempt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HarnessAuthAttempt _$HarnessAuthAttemptFromJson(Map<String, dynamic> json) =>
    _HarnessAuthAttempt(
      id: json['id'] as String,
      account: json['account'] as String,
      provider: json['provider'] as String,
      status: $enumDecode(_$HarnessAuthAttemptStatusEnumMap, json['status'],
          unknownValue: HarnessAuthAttemptStatus.unknown),
      lastError: json['last_error'] as String?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
    );

Map<String, dynamic> _$HarnessAuthAttemptToJson(_HarnessAuthAttempt instance) =>
    <String, dynamic>{
      'id': instance.id,
      'account': instance.account,
      'provider': instance.provider,
      'status': _$HarnessAuthAttemptStatusEnumMap[instance.status]!,
      'last_error': instance.lastError,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
    };

const _$HarnessAuthAttemptStatusEnumMap = {
  HarnessAuthAttemptStatus.starting: 'starting',
  HarnessAuthAttemptStatus.awaiting_input: 'awaiting_input',
  HarnessAuthAttemptStatus.succeeded: 'succeeded',
  HarnessAuthAttemptStatus.failed: 'failed',
  HarnessAuthAttemptStatus.expired: 'expired',
  HarnessAuthAttemptStatus.cancelled: 'cancelled',
  HarnessAuthAttemptStatus.unknown: '__unknown__',
};
