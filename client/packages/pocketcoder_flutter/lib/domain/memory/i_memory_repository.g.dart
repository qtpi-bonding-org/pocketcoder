// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'i_memory_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MemoryAccountSummary _$MemoryAccountSummaryFromJson(
        Map<String, dynamic> json) =>
    _MemoryAccountSummary(
      accountId: json['account_id'] as String,
      agentProfileId: json['agent_profile_id'] as String,
      agentName: json['agent_name'] as String,
      observations: (json['observations'] as num?)?.toInt() ?? 0,
      interpretations: (json['interpretations'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MemoryAccountSummaryToJson(
        _MemoryAccountSummary instance) =>
    <String, dynamic>{
      'account_id': instance.accountId,
      'agent_profile_id': instance.agentProfileId,
      'agent_name': instance.agentName,
      'observations': instance.observations,
      'interpretations': instance.interpretations,
    };

_MemoryObservation _$MemoryObservationFromJson(Map<String, dynamic> json) =>
    _MemoryObservation(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      author: json['author'] as String,
      body: json['body'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      retrievedAt: json['retrieved_at'] as String,
    );

Map<String, dynamic> _$MemoryObservationToJson(_MemoryObservation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'account_id': instance.accountId,
      'author': instance.author,
      'body': instance.body,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'retrieved_at': instance.retrievedAt,
    };

_MemoryInterpretation _$MemoryInterpretationFromJson(
        Map<String, dynamic> json) =>
    _MemoryInterpretation(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      author: json['author'] as String,
      body: json['body'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      retrievedAt: json['retrieved_at'] as String,
      linkedObservations: (json['linked_observations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$MemoryInterpretationToJson(
        _MemoryInterpretation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'account_id': instance.accountId,
      'author': instance.author,
      'body': instance.body,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'retrieved_at': instance.retrievedAt,
      'linked_observations': instance.linkedObservations,
    };
