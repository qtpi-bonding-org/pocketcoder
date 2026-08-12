// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_permission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ToolPermission _$ToolPermissionFromJson(Map<String, dynamic> json) =>
    _ToolPermission(
      id: json['id'] as String,
      tool: json['tool'] as String,
      pattern: json['pattern'] as String,
      action: $enumDecode(_$ToolPermissionActionEnumMap, json['action'],
          unknownValue: ToolPermissionAction.unknown),
      active: json['active'] as bool?,
      pocoConfig: json['poco_config'] as String?,
    );

Map<String, dynamic> _$ToolPermissionToJson(_ToolPermission instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tool': instance.tool,
      'pattern': instance.pattern,
      'action': _$ToolPermissionActionEnumMap[instance.action]!,
      'active': instance.active,
      'poco_config': instance.pocoConfig,
    };

const _$ToolPermissionActionEnumMap = {
  ToolPermissionAction.allow: 'allow',
  ToolPermissionAction.ask: 'ask',
  ToolPermissionAction.deny: 'deny',
  ToolPermissionAction.unknown: '__unknown__',
};
