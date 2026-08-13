// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Skill _$SkillFromJson(Map<String, dynamic> json) => _Skill(
      id: json['id'] as String,
      user: json['user'] as String?,
      isSystem: json['is_system'] as bool?,
      name: json['name'] as String,
      description: json['description'] as String,
      content: json['content'] as String,
      metadata: json['metadata'],
      active: json['active'] as bool?,
    );

Map<String, dynamic> _$SkillToJson(_Skill instance) => <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'is_system': instance.isSystem,
      'name': instance.name,
      'description': instance.description,
      'content': instance.content,
      'metadata': instance.metadata,
      'active': instance.active,
    };
