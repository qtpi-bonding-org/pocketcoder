// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Skill _$SkillFromJson(Map<String, dynamic> json) => _Skill(
      name: json['name'] as String,
      description: json['description'] as String,
      content: json['content'] as String,
      path: json['path'] as String,
      global: json['global'] as bool,
      system: json['system'] as bool? ?? false,
    );

Map<String, dynamic> _$SkillToJson(_Skill instance) => <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'content': instance.content,
      'path': instance.path,
      'global': instance.global,
      'system': instance.system,
    };
