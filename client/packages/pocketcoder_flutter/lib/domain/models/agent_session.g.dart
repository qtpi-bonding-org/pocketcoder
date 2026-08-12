// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AgentSession _$AgentSessionFromJson(Map<String, dynamic> json) =>
    _AgentSession(
      id: json['id'] as String,
      chat: json['chat'] as String,
      user: json['user'] as String,
      acpSessionId: json['acp_session_id'] as String,
      harnessVersion: json['harness_version'] as String?,
      modelProvider: json['model_provider'] as String?,
      harnessInstance: json['harness_instance'] as String?,
    );

Map<String, dynamic> _$AgentSessionToJson(_AgentSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'chat': instance.chat,
      'user': instance.user,
      'acp_session_id': instance.acpSessionId,
      'harness_version': instance.harnessVersion,
      'model_provider': instance.modelProvider,
      'harness_instance': instance.harnessInstance,
    };
