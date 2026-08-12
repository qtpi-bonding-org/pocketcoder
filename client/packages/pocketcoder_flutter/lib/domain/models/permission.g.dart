// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Permission _$PermissionFromJson(Map<String, dynamic> json) => _Permission(
      id: json['id'] as String,
      aiEnginePermissionId: json['ai_engine_permission_id'] as String,
      sessionId: json['session_id'] as String,
      permission: json['permission'] as String,
      patterns: json['patterns'],
      metadata: json['metadata'],
      status: $enumDecode(_$PermissionStatusEnumMap, json['status'],
          unknownValue: PermissionStatus.unknown),
      message: json['message'] as String?,
      source: json['source'] as String?,
      messageId: json['message_id'] as String?,
      callId: json['call_id'] as String?,
      challenge: json['challenge'] as String?,
      chat: json['chat'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] == null
          ? null
          : DateTime.parse(json['approved_at'] as String),
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
      acpRequestId: json['acp_request_id'] as String?,
      acpSessionId: json['acp_session_id'] as String?,
      toolName: json['tool_name'] as String?,
      toolInput: json['tool_input'],
      description: json['description'] as String?,
      permissionOptions: json['permission_options'],
      acpStatus: $enumDecodeNullable(
          _$PermissionAcpStatusEnumMap, json['acp_status'],
          unknownValue: PermissionAcpStatus.unknown),
      selectedOptionId: json['selected_option_id'] as String?,
      acpMessageId: json['acp_message_id'] as String?,
      toolCallId: json['tool_call_id'] as String?,
    );

Map<String, dynamic> _$PermissionToJson(_Permission instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ai_engine_permission_id': instance.aiEnginePermissionId,
      'session_id': instance.sessionId,
      'permission': instance.permission,
      'patterns': instance.patterns,
      'metadata': instance.metadata,
      'status': _$PermissionStatusEnumMap[instance.status]!,
      'message': instance.message,
      'source': instance.source,
      'message_id': instance.messageId,
      'call_id': instance.callId,
      'challenge': instance.challenge,
      'chat': instance.chat,
      'approved_by': instance.approvedBy,
      'approved_at': instance.approvedAt?.toIso8601String(),
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
      'acp_request_id': instance.acpRequestId,
      'acp_session_id': instance.acpSessionId,
      'tool_name': instance.toolName,
      'tool_input': instance.toolInput,
      'description': instance.description,
      'permission_options': instance.permissionOptions,
      'acp_status': _$PermissionAcpStatusEnumMap[instance.acpStatus],
      'selected_option_id': instance.selectedOptionId,
      'acp_message_id': instance.acpMessageId,
      'tool_call_id': instance.toolCallId,
    };

const _$PermissionStatusEnumMap = {
  PermissionStatus.draft: 'draft',
  PermissionStatus.authorized: 'authorized',
  PermissionStatus.denied: 'denied',
  PermissionStatus.unknown: '__unknown__',
};

const _$PermissionAcpStatusEnumMap = {
  PermissionAcpStatus.pending: 'pending',
  PermissionAcpStatus.allow_once: 'allow_once',
  PermissionAcpStatus.allow_always: 'allow_always',
  PermissionAcpStatus.deny: 'deny',
  PermissionAcpStatus.unknown: '__unknown__',
};
