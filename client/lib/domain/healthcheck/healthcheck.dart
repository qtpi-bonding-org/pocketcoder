import 'package:freezed_annotation/freezed_annotation.dart';

part 'healthcheck.freezed.dart';
part 'healthcheck.g.dart';

@freezed
class Healthcheck with _$Healthcheck {
  const factory Healthcheck({
    required String id,
    required String name,
    required HealthcheckStatus status,
    @JsonKey(name: 'last_ping') DateTime? lastPing,
    DateTime? created,
    DateTime? updated,
  }) = _Healthcheck;

  factory Healthcheck.fromJson(Map<String, dynamic> json) =>
      _$HealthcheckFromJson(json);
}

enum HealthcheckStatus {
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
}
