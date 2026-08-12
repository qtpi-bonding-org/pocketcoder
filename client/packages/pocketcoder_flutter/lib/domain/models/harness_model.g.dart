// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harness_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HarnessModel _$HarnessModelFromJson(Map<String, dynamic> json) =>
    _HarnessModel(
      id: json['id'] as String,
      harness: json['harness'] as String,
      model: json['model'] as String,
      harnessModelId: json['harness_model_id'] as String,
      isDefault: json['is_default'] as bool?,
    );

Map<String, dynamic> _$HarnessModelToJson(_HarnessModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'harness': instance.harness,
      'model': instance.model,
      'harness_model_id': instance.harnessModelId,
      'is_default': instance.isDefault,
    };
