// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harness_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HarnessAccount _$HarnessAccountFromJson(Map<String, dynamic> json) =>
    _HarnessAccount(
      id: json['id'] as String,
      harness: json['harness'] as String,
      owner: json['owner'] as String,
      name: json['name'] as String,
      visibility: $enumDecode(
          _$HarnessAccountVisibilityEnumMap, json['visibility'],
          unknownValue: HarnessAccountVisibility.unknown),
      credentialMode: $enumDecode(
          _$HarnessAccountCredentialModeEnumMap, json['credential_mode'],
          unknownValue: HarnessAccountCredentialMode.unknown),
      providerKey: json['provider_key'] as String?,
      status: $enumDecode(_$HarnessAccountStatusEnumMap, json['status'],
          unknownValue: HarnessAccountStatus.unknown),
      lastError: json['last_error'] as String?,
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
    );

Map<String, dynamic> _$HarnessAccountToJson(_HarnessAccount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'harness': instance.harness,
      'owner': instance.owner,
      'name': instance.name,
      'visibility': _$HarnessAccountVisibilityEnumMap[instance.visibility]!,
      'credential_mode':
          _$HarnessAccountCredentialModeEnumMap[instance.credentialMode]!,
      'provider_key': instance.providerKey,
      'status': _$HarnessAccountStatusEnumMap[instance.status]!,
      'last_error': instance.lastError,
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
    };

const _$HarnessAccountVisibilityEnumMap = {
  HarnessAccountVisibility.personal: 'personal',
  HarnessAccountVisibility.deployment: 'deployment',
  HarnessAccountVisibility.unknown: '__unknown__',
};

const _$HarnessAccountCredentialModeEnumMap = {
  HarnessAccountCredentialMode.account: 'account',
  HarnessAccountCredentialMode.api_key: 'api_key',
  HarnessAccountCredentialMode.none: 'none',
  HarnessAccountCredentialMode.unknown: '__unknown__',
};

const _$HarnessAccountStatusEnumMap = {
  HarnessAccountStatus.disconnected: 'disconnected',
  HarnessAccountStatus.connecting: 'connecting',
  HarnessAccountStatus.connected: 'connected',
  HarnessAccountStatus.error: 'error',
  HarnessAccountStatus.needs_api_key: 'needs_api_key',
  HarnessAccountStatus.unknown: '__unknown__',
};
