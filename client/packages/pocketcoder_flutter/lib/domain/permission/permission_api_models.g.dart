// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PermissionResponse _$PermissionResponseFromJson(Map<String, dynamic> json) =>
    _PermissionResponse(
      permitted: json['permitted'] as bool,
      id: json['id'] as String,
      status: json['status'] as String,
    );

Map<String, dynamic> _$PermissionResponseToJson(_PermissionResponse instance) =>
    <String, dynamic>{
      'permitted': instance.permitted,
      'id': instance.id,
      'status': instance.status,
    };
