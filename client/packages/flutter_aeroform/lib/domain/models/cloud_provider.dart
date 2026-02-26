import 'package:freezed_annotation/freezed_annotation.dart';

part 'cloud_provider.freezed.dart';
part 'cloud_provider.g.dart';

@freezed
class CloudInstance with _$CloudInstance {
  const factory CloudInstance({
    required String id,
    required String label,
    required String ipAddress,
    required CloudInstanceStatus status,
    required DateTime created,
    required String region,
    required String planType,
    required String provider,
  }) = _CloudInstance;

  factory CloudInstance.fromJson(Map<String, dynamic> json) =>
      _$CloudInstanceFromJson(json);
}

@freezed
class InstancePlan with _$InstancePlan {
  const factory InstancePlan({
    required String id,
    required String name,
    required int memoryMB,
    required int vcpus,
    required int diskGB,
    required double monthlyPriceUSD,
    required bool recommended,
  }) = _InstancePlan;

  factory InstancePlan.fromJson(Map<String, dynamic> json) =>
      _$InstancePlanFromJson(json);
}

@freezed
class Region with _$Region {
  const factory Region({
    required String id,
    required String name,
    required String country,
    required String city,
  }) = _Region;

  factory Region.fromJson(Map<String, dynamic> json) => _$RegionFromJson(json);
}

enum CloudInstanceStatus {
  creating,
  provisioning,
  running,
  offline,
  failed,
}