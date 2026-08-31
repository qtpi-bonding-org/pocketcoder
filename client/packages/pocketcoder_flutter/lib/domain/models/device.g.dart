// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Device _$DeviceFromJson(Map<String, dynamic> json) => _Device(
      id: json['id'] as String,
      user: json['user'] as String,
      name: json['name'] as String,
      pushToken: json['push_token'] as String,
      pushService: $enumDecode(_$DevicePushServiceEnumMap, json['push_service'],
          unknownValue: DevicePushService.unknown),
      isActive: json['is_active'] as bool?,
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
      platform: $enumDecodeNullable(_$DevicePlatformEnumMap, json['platform'],
          unknownValue: DevicePlatform.unknown),
      pushToStartToken: json['push_to_start_token'] as String?,
    );

Map<String, dynamic> _$DeviceToJson(_Device instance) => <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'name': instance.name,
      'push_token': instance.pushToken,
      'push_service': _$DevicePushServiceEnumMap[instance.pushService]!,
      'is_active': instance.isActive,
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
      'platform': _$DevicePlatformEnumMap[instance.platform],
      'push_to_start_token': instance.pushToStartToken,
    };

const _$DevicePushServiceEnumMap = {
  DevicePushService.fcm: 'fcm',
  DevicePushService.unifiedpush: 'unifiedpush',
  DevicePushService.unknown: '__unknown__',
};

const _$DevicePlatformEnumMap = {
  DevicePlatform.ios: 'ios',
  DevicePlatform.android: 'android',
  DevicePlatform.unknown: '__unknown__',
};
