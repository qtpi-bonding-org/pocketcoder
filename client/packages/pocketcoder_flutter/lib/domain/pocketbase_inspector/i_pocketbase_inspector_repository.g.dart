// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'i_pocketbase_inspector_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PocketbaseChatSummary _$PocketbaseChatSummaryFromJson(
        Map<String, dynamic> json) =>
    _PocketbaseChatSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      turn: json['turn'] as String,
      archived: json['archived'] as bool? ?? false,
      createdAt: json['created_at'] as String,
      lastActive: json['last_active'] as String,
    );

Map<String, dynamic> _$PocketbaseChatSummaryToJson(
        _PocketbaseChatSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'turn': instance.turn,
      'archived': instance.archived,
      'created_at': instance.createdAt,
      'last_active': instance.lastActive,
    };
