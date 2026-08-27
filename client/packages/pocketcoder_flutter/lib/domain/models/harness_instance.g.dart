// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harness_instance.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HarnessInstance _$HarnessInstanceFromJson(Map<String, dynamic> json) =>
    _HarnessInstance(
      id: json['id'] as String,
      harness: json['harness'] as String,
      user: json['user'] as String?,
      harnessModel: json['harness_model'] as String?,
      oauthAccount: json['oauth_account'] as String?,
      launchKey: json['launch_key'] as String?,
      containerName: json['container_name'] as String,
      acpEndpoint: json['acp_endpoint'] as String?,
      secret: json['secret'] as String?,
      status: $enumDecode(_$HarnessInstanceStatusEnumMap, json['status'],
          unknownValue: HarnessInstanceStatus.unknown),
      lastError: json['last_error'] as String?,
      managed: json['managed'] as bool?,
      lastUsed: json['last_used'] as String?,
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
    );

Map<String, dynamic> _$HarnessInstanceToJson(_HarnessInstance instance) =>
    <String, dynamic>{
      'id': instance.id,
      'harness': instance.harness,
      'user': instance.user,
      'harness_model': instance.harnessModel,
      'oauth_account': instance.oauthAccount,
      'launch_key': instance.launchKey,
      'container_name': instance.containerName,
      'acp_endpoint': instance.acpEndpoint,
      'secret': instance.secret,
      'status': _$HarnessInstanceStatusEnumMap[instance.status]!,
      'last_error': instance.lastError,
      'managed': instance.managed,
      'last_used': instance.lastUsed,
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
    };

const _$HarnessInstanceStatusEnumMap = {
  HarnessInstanceStatus.pending: 'pending',
  HarnessInstanceStatus.running: 'running',
  HarnessInstanceStatus.stopped: 'stopped',
  HarnessInstanceStatus.error: 'error',
  HarnessInstanceStatus.unknown: '__unknown__',
};
