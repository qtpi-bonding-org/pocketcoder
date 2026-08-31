// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harness_provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HarnessProvider _$HarnessProviderFromJson(Map<String, dynamic> json) =>
    _HarnessProvider(
      id: json['id'] as String,
      harness: json['harness'] as String,
      provider: json['provider'] as String,
      supportsOauth: json['supports_oauth'] as bool?,
      oauthAuthenticator: json['oauth_authenticator'] as String?,
      apiKeyEnvOverride: json['api_key_env_override'] as String?,
      isPinned: json['is_pinned'] as bool?,
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
    );

Map<String, dynamic> _$HarnessProviderToJson(_HarnessProvider instance) =>
    <String, dynamic>{
      'id': instance.id,
      'harness': instance.harness,
      'provider': instance.provider,
      'supports_oauth': instance.supportsOauth,
      'oauth_authenticator': instance.oauthAuthenticator,
      'api_key_env_override': instance.apiKeyEnvOverride,
      'is_pinned': instance.isPinned,
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
    };
