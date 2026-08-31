// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'i_observability_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ContainerInfo _$ContainerInfoFromJson(Map<String, dynamic> json) =>
    _ContainerInfo(
      name: json['name'] as String,
      state: json['state'] as String,
      status: json['status'] as String,
    );

Map<String, dynamic> _$ContainerInfoToJson(_ContainerInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'state': instance.state,
      'status': instance.status,
    };

_OperationalTask _$OperationalTaskFromJson(Map<String, dynamic> json) =>
    _OperationalTask(
      id: json['id'] as String,
      status: json['status'] as String,
      sender: json['sender'] as String,
      receiver: json['receiver'] as String,
      summary: json['summary'] as String,
      timestamp: json['timestamp'] as String,
    );

Map<String, dynamic> _$OperationalTaskToJson(_OperationalTask instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'sender': instance.sender,
      'receiver': instance.receiver,
      'summary': instance.summary,
      'timestamp': instance.timestamp,
    };

_TokenUsage _$TokenUsageFromJson(Map<String, dynamic> json) => _TokenUsage(
      model: json['model'] as String,
      tokens: (json['tokens'] as num).toInt(),
    );

Map<String, dynamic> _$TokenUsageToJson(_TokenUsage instance) =>
    <String, dynamic>{
      'model': instance.model,
      'tokens': instance.tokens,
    };
