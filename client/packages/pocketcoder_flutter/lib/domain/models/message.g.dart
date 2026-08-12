// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Message _$MessageFromJson(Map<String, dynamic> json) => _Message(
      id: json['id'] as String,
      chat: json['chat'] as String,
      role: $enumDecode(_$MessageRoleEnumMap, json['role'],
          unknownValue: MessageRole.unknown),
      engineMessageStatus: $enumDecodeNullable(
          _$MessageEngineMessageStatusEnumMap, json['engine_message_status'],
          unknownValue: MessageEngineMessageStatus.unknown),
      userMessageStatus: $enumDecodeNullable(
          _$MessageUserMessageStatusEnumMap, json['user_message_status'],
          unknownValue: MessageUserMessageStatus.unknown),
      aiEngineMessageId: json['ai_engine_message_id'] as String?,
      parentId: json['parent_id'] as String?,
      parts: json['parts'],
      errorDomain: $enumDecodeNullable(
          _$MessageErrorDomainEnumMap, json['error_domain'],
          unknownValue: MessageErrorDomain.unknown),
      errorPayload: json['error_payload'],
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
      content: json['content'],
      acpStatus: $enumDecodeNullable(
          _$MessageAcpStatusEnumMap, json['acp_status'],
          unknownValue: MessageAcpStatus.unknown),
      usage: json['usage'],
      cost: json['cost'],
    );

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
      'id': instance.id,
      'chat': instance.chat,
      'role': _$MessageRoleEnumMap[instance.role]!,
      'engine_message_status':
          _$MessageEngineMessageStatusEnumMap[instance.engineMessageStatus],
      'user_message_status':
          _$MessageUserMessageStatusEnumMap[instance.userMessageStatus],
      'ai_engine_message_id': instance.aiEngineMessageId,
      'parent_id': instance.parentId,
      'parts': instance.parts,
      'error_domain': _$MessageErrorDomainEnumMap[instance.errorDomain],
      'error_payload': instance.errorPayload,
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
      'content': instance.content,
      'acp_status': _$MessageAcpStatusEnumMap[instance.acpStatus],
      'usage': instance.usage,
      'cost': instance.cost,
    };

const _$MessageRoleEnumMap = {
  MessageRole.user: 'user',
  MessageRole.assistant: 'assistant',
  MessageRole.system: 'system',
  MessageRole.unknown: '__unknown__',
};

const _$MessageEngineMessageStatusEnumMap = {
  MessageEngineMessageStatus.processing: 'processing',
  MessageEngineMessageStatus.completed: 'completed',
  MessageEngineMessageStatus.failed: 'failed',
  MessageEngineMessageStatus.aborted: 'aborted',
  MessageEngineMessageStatus.unknown: '__unknown__',
};

const _$MessageUserMessageStatusEnumMap = {
  MessageUserMessageStatus.pending: 'pending',
  MessageUserMessageStatus.sending: 'sending',
  MessageUserMessageStatus.delivered: 'delivered',
  MessageUserMessageStatus.failed: 'failed',
  MessageUserMessageStatus.unknown: '__unknown__',
};

const _$MessageErrorDomainEnumMap = {
  MessageErrorDomain.infrastructure: 'infrastructure',
  MessageErrorDomain.provider: 'provider',
  MessageErrorDomain.unknown: '__unknown__',
};

const _$MessageAcpStatusEnumMap = {
  MessageAcpStatus.streaming: 'streaming',
  MessageAcpStatus.completed: 'completed',
  MessageAcpStatus.failed: 'failed',
  MessageAcpStatus.cancelled: 'cancelled',
  MessageAcpStatus.unknown: '__unknown__',
};
