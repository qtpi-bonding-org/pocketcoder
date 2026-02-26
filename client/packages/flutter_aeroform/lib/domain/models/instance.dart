import 'package:freezed_annotation/freezed_annotation.dart';

part 'instance.freezed.dart';
part 'instance.g.dart';

@freezed
class Instance with _$Instance {
  const Instance._();

  const factory Instance({
    required String id,
    required String label,
    required String ipAddress,
    required InstanceStatus status,
    required DateTime created,
    required String region,
    required String planType,
    required String provider,
    String? adminEmail,
  }) = _Instance;

  String get httpsUrl => 'https://$ipAddress';

  factory Instance.fromJson(Map<String, dynamic> json) =>
      _$InstanceFromJson(json);
}

enum InstanceStatus {
  creating,
  provisioning,
  running,
  offline,
  failed,
}