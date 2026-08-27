// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Provider _$ProviderFromJson(Map<String, dynamic> json) => _Provider(
      id: json['id'] as String,
      providerId: json['provider_id'] as String,
      name: json['name'] as String,
      apiKeyEnv: json['api_key_env'] as String?,
    );

Map<String, dynamic> _$ProviderToJson(_Provider instance) => <String, dynamic>{
      'id': instance.id,
      'provider_id': instance.providerId,
      'name': instance.name,
      'api_key_env': instance.apiKeyEnv,
    };
