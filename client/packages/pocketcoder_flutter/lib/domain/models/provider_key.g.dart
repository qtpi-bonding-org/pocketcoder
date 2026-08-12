// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_key.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProviderKey _$ProviderKeyFromJson(Map<String, dynamic> json) => _ProviderKey(
      id: json['id'] as String,
      user: json['user'] as String,
      provider: json['provider'] as String,
      envVars: json['env_vars'],
    );

Map<String, dynamic> _$ProviderKeyToJson(_ProviderKey instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'provider': instance.provider,
      'env_vars': instance.envVars,
    };
