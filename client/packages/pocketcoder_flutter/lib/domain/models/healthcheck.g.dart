// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'healthcheck.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Healthcheck _$HealthcheckFromJson(Map<String, dynamic> json) => _Healthcheck(
      id: json['id'] as String,
      name: json['name'] as String,
      status: $enumDecode(_$HealthcheckStatusEnumMap, json['status'],
          unknownValue: HealthcheckStatus.unknown),
      lastPing: json['last_ping'] == null
          ? null
          : DateTime.parse(json['last_ping'] as String),
    );

Map<String, dynamic> _$HealthcheckToJson(_Healthcheck instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'status': _$HealthcheckStatusEnumMap[instance.status]!,
      'last_ping': instance.lastPing?.toIso8601String(),
    };

const _$HealthcheckStatusEnumMap = {
  HealthcheckStatus.starting: 'starting',
  HealthcheckStatus.ready: 'ready',
  HealthcheckStatus.degraded: 'degraded',
  HealthcheckStatus.offline: 'offline',
  HealthcheckStatus.error: 'error',
  HealthcheckStatus.unknown: '__unknown__',
};
