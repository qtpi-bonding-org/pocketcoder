// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'poco_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PocoConfig _$PocoConfigFromJson(Map<String, dynamic> json) => _PocoConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      user: json['user'] as String?,
      isSystem: json['is_system'] as bool?,
      systemPrompt: json['system_prompt'] as String?,
      workspaceFolders: json['workspace_folders'],
      acpMcpServers: json['acp_mcp_servers'],
      isDefault: json['is_default'] as bool?,
      permissionMode: json['permission_mode'] as String?,
    );

Map<String, dynamic> _$PocoConfigToJson(_PocoConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'user': instance.user,
      'is_system': instance.isSystem,
      'system_prompt': instance.systemPrompt,
      'workspace_folders': instance.workspaceFolders,
      'acp_mcp_servers': instance.acpMcpServers,
      'is_default': instance.isDefault,
      'permission_mode': instance.permissionMode,
    };
