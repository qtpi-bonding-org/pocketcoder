// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Model _$ModelFromJson(Map<String, dynamic> json) => _Model(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['display_name'] as String?,
      provider: json['provider'] as String,
      contextWindow: (json['context_window'] as num?)?.toDouble(),
      description: json['description'] as String?,
    );

Map<String, dynamic> _$ModelToJson(_Model instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'display_name': instance.displayName,
      'provider': instance.provider,
      'context_window': instance.contextWindow,
      'description': instance.description,
    };
