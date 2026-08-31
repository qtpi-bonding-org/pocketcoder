// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_api_key.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProviderApiKey _$ProviderApiKeyFromJson(Map<String, dynamic> json) =>
    _ProviderApiKey(
      id: json['id'] as String,
      owner: json['owner'] as String,
      provider: json['provider'] as String,
      apiKey: json['api_key'] as String,
      baseUrl: json['base_url'] as String?,
      extraEnv: json['extra_env'],
      lastVerified: json['last_verified'] == null
          ? null
          : DateTime.parse(json['last_verified'] as String),
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
    );

Map<String, dynamic> _$ProviderApiKeyToJson(_ProviderApiKey instance) =>
    <String, dynamic>{
      'id': instance.id,
      'owner': instance.owner,
      'provider': instance.provider,
      'api_key': instance.apiKey,
      'base_url': instance.baseUrl,
      'extra_env': instance.extraEnv,
      'last_verified': instance.lastVerified?.toIso8601String(),
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
    };
