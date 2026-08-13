// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission_mode.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PermissionMode _$PermissionModeFromJson(Map<String, dynamic> json) =>
    _PermissionMode(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      baseSessionMode: $enumDecode(
          _$PermissionModeBaseSessionModeEnumMap, json['base_session_mode'],
          unknownValue: PermissionModeBaseSessionMode.unknown),
      user: json['user'] as String?,
      isSystem: json['is_system'] as bool?,
      isDefault: json['is_default'] as bool?,
    );

Map<String, dynamic> _$PermissionModeToJson(_PermissionMode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'base_session_mode':
          _$PermissionModeBaseSessionModeEnumMap[instance.baseSessionMode]!,
      'user': instance.user,
      'is_system': instance.isSystem,
      'is_default': instance.isDefault,
    };

const _$PermissionModeBaseSessionModeEnumMap = {
  PermissionModeBaseSessionMode.auto: 'auto',
  PermissionModeBaseSessionMode.approve: 'approve',
  PermissionModeBaseSessionMode.smart_approve: 'smart_approve',
  PermissionModeBaseSessionMode.chat: 'chat',
  PermissionModeBaseSessionMode.unknown: '__unknown__',
};
