// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Chat _$ChatFromJson(Map<String, dynamic> json) => _Chat(
      id: json['id'] as String,
      title: json['title'] as String,
      user: json['user'] as String,
      lastActive: json['last_active'] == null
          ? null
          : DateTime.parse(json['last_active'] as String),
      preview: json['preview'] as String?,
      firstMessage: json['first_message'] as String?,
      turn: $enumDecodeNullable(_$ChatTurnEnumMap, json['turn'],
          unknownValue: ChatTurn.unknown),
      description: json['description'] as String?,
      archived: json['archived'] as bool?,
      tags: json['tags'] as String?,
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
      agentProfile: json['agent_profile'] as String?,
      harnessModelOverride: json['harness_model_override'] as String?,
      ollamaModelOverride: json['ollama_model_override'] as String?,
      harness: json['harness'] as String?,
      workspaceOverride: json['workspace_override'],
      monitored: json['monitored'] as bool?,
    );

Map<String, dynamic> _$ChatToJson(_Chat instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'user': instance.user,
      'last_active': instance.lastActive?.toIso8601String(),
      'preview': instance.preview,
      'first_message': instance.firstMessage,
      'turn': _$ChatTurnEnumMap[instance.turn],
      'description': instance.description,
      'archived': instance.archived,
      'tags': instance.tags,
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
      'agent_profile': instance.agentProfile,
      'harness_model_override': instance.harnessModelOverride,
      'ollama_model_override': instance.ollamaModelOverride,
      'harness': instance.harness,
      'workspace_override': instance.workspaceOverride,
      'monitored': instance.monitored,
    };

const _$ChatTurnEnumMap = {
  ChatTurn.user: 'user',
  ChatTurn.assistant: 'assistant',
  ChatTurn.unknown: '__unknown__',
};
