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
    );

Map<String, dynamic> _$DeviceToJson(_Device instance) => <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'name': instance.name,
      'push_token': instance.pushToken,
      'push_service': _$DevicePushServiceEnumMap[instance.pushService]!,
      'is_active': instance.isActive,
    };

const _$DevicePushServiceEnumMap = {
  DevicePushService.fcm: 'fcm',
  DevicePushService.unifiedpush: 'unifiedpush',
  DevicePushService.unknown: '__unknown__',
};
