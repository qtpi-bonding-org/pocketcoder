// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatar: json['avatar'] as String?,
      role: $enumDecodeNullable(_$UserRoleEnumMap, json['role']),
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
    );

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'name': instance.name,
      'avatar': instance.avatar,
      'role': _$UserRoleEnumMap[instance.role],
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
    };

const _$UserRoleEnumMap = {
  UserRole.admin: 'admin',
  UserRole.agent: 'agent',
  UserRole.user: 'user',
  UserRole.unknown: '',
};
