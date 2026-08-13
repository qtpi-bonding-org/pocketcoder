// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harness_account_selection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HarnessAccountSelection _$HarnessAccountSelectionFromJson(
        Map<String, dynamic> json) =>
    _HarnessAccountSelection(
      id: json['id'] as String,
      user: json['user'] as String,
      harness: json['harness'] as String,
      account: json['account'] as String,
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
    );

Map<String, dynamic> _$HarnessAccountSelectionToJson(
        _HarnessAccountSelection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'harness': instance.harness,
      'account': instance.account,
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
    };
