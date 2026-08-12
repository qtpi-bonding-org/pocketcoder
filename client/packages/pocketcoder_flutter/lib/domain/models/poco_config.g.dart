// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'poco_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PocoConfig _$PocoConfigFromJson(Map<String, dynamic> json) => _PocoConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      harnessModel: json['harness_model'] as String,
      systemPrompt: json['system_prompt'] as String?,
      workspaceFolders: json['workspace_folders'],
      acpMcpServers: json['acp_mcp_servers'],
      isDefault: json['is_default'] as bool?,
      mode: $enumDecodeNullable(_$PocoConfigModeEnumMap, json['mode'],
          unknownValue: PocoConfigMode.unknown),
    );

Map<String, dynamic> _$PocoConfigToJson(_PocoConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'harness_model': instance.harnessModel,
      'system_prompt': instance.systemPrompt,
      'workspace_folders': instance.workspaceFolders,
      'acp_mcp_servers': instance.acpMcpServers,
      'is_default': instance.isDefault,
      'mode': _$PocoConfigModeEnumMap[instance.mode],
    };

const _$PocoConfigModeEnumMap = {
  PocoConfigMode.auto: 'auto',
  PocoConfigMode.approve: 'approve',
  PocoConfigMode.smart_approve: 'smart_approve',
  PocoConfigMode.chat: 'chat',
  PocoConfigMode.unknown: '__unknown__',
};
