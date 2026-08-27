// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credential_selection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CredentialSelection _$CredentialSelectionFromJson(Map<String, dynamic> json) =>
    _CredentialSelection(
      id: json['id'] as String,
      user: json['user'] as String,
      harness: json['harness'] as String,
      provider: json['provider'] as String,
      mode: $enumDecode(_$CredentialSelectionModeEnumMap, json['mode'],
          unknownValue: CredentialSelectionMode.unknown),
      oauthAccount: json['oauth_account'] as String?,
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
    );

Map<String, dynamic> _$CredentialSelectionToJson(
        _CredentialSelection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'harness': instance.harness,
      'provider': instance.provider,
      'mode': _$CredentialSelectionModeEnumMap[instance.mode]!,
      'oauth_account': instance.oauthAccount,
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
    };

const _$CredentialSelectionModeEnumMap = {
  CredentialSelectionMode.oauth: 'oauth',
  CredentialSelectionMode.apiKey: 'api_key',
  CredentialSelectionMode.none: 'none',
  CredentialSelectionMode.unknown: '__unknown__',
};
