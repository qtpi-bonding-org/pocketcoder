// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cognee_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CogneeConfig _$CogneeConfigFromJson(Map<String, dynamic> json) =>
    _CogneeConfig(
      id: json['id'] as String,
      llmProvider: json['llm_provider'] as String,
      llmModel: json['llm_model'] as String,
      llmBaseUrl: json['llm_base_url'] as String?,
      llmApiKey: json['llm_api_key'] as String,
    );

Map<String, dynamic> _$CogneeConfigToJson(_CogneeConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'llm_provider': instance.llmProvider,
      'llm_model': instance.llmModel,
      'llm_base_url': instance.llmBaseUrl,
      'llm_api_key': instance.llmApiKey,
    };
