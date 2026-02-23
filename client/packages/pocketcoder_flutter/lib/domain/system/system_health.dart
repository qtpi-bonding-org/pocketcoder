import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_health.freezed.dart';
part 'system_health.g.dart';

@freezed
class SystemHealth with _$SystemHealth {
  const factory SystemHealth({
    required String id,
    required String name,
    required HealthStatus status,
    DateTime? lastPing,
    DateTime? created,
    DateTime? updated,
  }) = _SystemHealth;

  factory SystemHealth.fromJson(Map<String, dynamic> json) =>
      _$SystemHealthFromJson(json);
}

enum HealthStatus {
  @JsonValue('starting')
  starting,
  @JsonValue('ready')
  ready,
  @JsonValue('degraded')
  degraded,
  @JsonValue('offline')
  offline,
  @JsonValue('error')
  error,
  @JsonValue('')
  unknown,
}
