// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harness_oauth_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HarnessOauthAccount _$HarnessOauthAccountFromJson(Map<String, dynamic> json) =>
    _HarnessOauthAccount(
      id: json['id'] as String,
      harness: json['harness'] as String,
      provider: json['provider'] as String,
      owner: json['owner'] as String,
      name: json['name'] as String,
      visibility: $enumDecode(
          _$HarnessOauthAccountVisibilityEnumMap, json['visibility'],
          unknownValue: HarnessOauthAccountVisibility.unknown),
      status: $enumDecode(_$HarnessOauthAccountStatusEnumMap, json['status'],
          unknownValue: HarnessOauthAccountStatus.unknown),
      lastError: json['last_error'] as String?,
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
    );

Map<String, dynamic> _$HarnessOauthAccountToJson(
        _HarnessOauthAccount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'harness': instance.harness,
      'provider': instance.provider,
      'owner': instance.owner,
      'name': instance.name,
      'visibility':
          _$HarnessOauthAccountVisibilityEnumMap[instance.visibility]!,
      'status': _$HarnessOauthAccountStatusEnumMap[instance.status]!,
      'last_error': instance.lastError,
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
    };

const _$HarnessOauthAccountVisibilityEnumMap = {
  HarnessOauthAccountVisibility.personal: 'personal',
  HarnessOauthAccountVisibility.deployment: 'deployment',
  HarnessOauthAccountVisibility.unknown: '__unknown__',
};

const _$HarnessOauthAccountStatusEnumMap = {
  HarnessOauthAccountStatus.disconnected: 'disconnected',
  HarnessOauthAccountStatus.connecting: 'connecting',
  HarnessOauthAccountStatus.connected: 'connected',
  HarnessOauthAccountStatus.error: 'error',
  HarnessOauthAccountStatus.unknown: '__unknown__',
};
