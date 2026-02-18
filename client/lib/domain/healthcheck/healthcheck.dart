import 'package:freezed_annotation/freezed_annotation.dart';

part 'healthcheck.freezed.dart';
part 'healthcheck.g.dart';

@freezed
class Healthcheck with _$Healthcheck {
  const factory Healthcheck({
    required String id,
    required String name,
    String? status,
    @JsonKey(name: 'last_ping') DateTime? lastPing,
    DateTime? created,
    DateTime? updated,
  }) = _Healthcheck;

  factory Healthcheck.fromJson(Map<String, dynamic> json) => _$HealthcheckFromJson(json);
}