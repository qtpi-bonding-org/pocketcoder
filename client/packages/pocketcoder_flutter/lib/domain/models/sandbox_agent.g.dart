// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sandbox_agent.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SandboxAgent _$SandboxAgentFromJson(Map<String, dynamic> json) =>
    _SandboxAgent(
      id: json['id'] as String,
      sandboxAgentId: json['sandbox_agent_id'] as String,
      delegatingAgentId: json['delegating_agent_id'] as String,
      tmuxWindowId: (json['tmux_window_id'] as num?)?.toDouble(),
      chat: json['chat'] as String?,
    );

Map<String, dynamic> _$SandboxAgentToJson(_SandboxAgent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sandbox_agent_id': instance.sandboxAgentId,
      'delegating_agent_id': instance.delegatingAgentId,
      'tmux_window_id': instance.tmuxWindowId,
      'chat': instance.chat,
    };
