import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'healthcheck.freezed.dart';
part 'healthcheck.g.dart';

@freezed
class Healthcheck with _$Healthcheck {
  const factory Healthcheck({
    required String id,
    required String name,
    @JsonKey(unknownEnumValue: HealthcheckStatus.unknown) required HealthcheckStatus status,
    DateTime? lastPing,
  }) = _Healthcheck;

  factory Healthcheck.fromRecord(RecordModel record) =>
      Healthcheck.fromJson(record.toJson());

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
  @JsonValue('__unknown__')
  unknown,
}
