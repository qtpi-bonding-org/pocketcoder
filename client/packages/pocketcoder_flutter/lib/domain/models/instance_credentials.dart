import 'package:freezed_annotation/freezed_annotation.dart';

part 'instance_credentials.freezed.dart';
part 'instance_credentials.g.dart';

@freezed
class InstanceCredentials with _$InstanceCredentials {
  const factory InstanceCredentials({
    required String instanceId,
    required String adminPassword,
    required String rootPassword,
    required String adminEmail,
  }) = _InstanceCredentials;

  factory InstanceCredentials.fromJson(Map<String, dynamic> json) =>
      _$InstanceCredentialsFromJson(json);
}