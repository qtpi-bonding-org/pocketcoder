// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harness_oauth_attempt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HarnessOauthAttempt _$HarnessOauthAttemptFromJson(Map<String, dynamic> json) =>
    _HarnessOauthAttempt(
      id: json['id'] as String,
      account: json['account'] as String,
      status: $enumDecode(_$HarnessOauthAttemptStatusEnumMap, json['status'],
          unknownValue: HarnessOauthAttemptStatus.unknown),
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

Map<String, dynamic> _$HarnessOauthAttemptToJson(
        _HarnessOauthAttempt instance) =>
    <String, dynamic>{
      'id': instance.id,
      'account': instance.account,
      'status': _$HarnessOauthAttemptStatusEnumMap[instance.status]!,
      'last_error': instance.lastError,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
    };

const _$HarnessOauthAttemptStatusEnumMap = {
  HarnessOauthAttemptStatus.starting: 'starting',
  HarnessOauthAttemptStatus.awaitingInput: 'awaiting_input',
  HarnessOauthAttemptStatus.succeeded: 'succeeded',
  HarnessOauthAttemptStatus.failed: 'failed',
  HarnessOauthAttemptStatus.expired: 'expired',
  HarnessOauthAttemptStatus.cancelled: 'cancelled',
  HarnessOauthAttemptStatus.unknown: '__unknown__',
};
