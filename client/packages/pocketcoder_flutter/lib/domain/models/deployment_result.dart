import 'package:freezed_annotation/freezed_annotation.dart';

part 'deployment_result.freezed.dart';
part 'deployment_result.g.dart';

@freezed
class DeploymentResult with _$DeploymentResult {
  const factory DeploymentResult({
    required String instanceId,
    required String ipAddress,
    required DeploymentStatus status,
    String? errorMessage,
  }) = _DeploymentResult;

  factory DeploymentResult.fromJson(Map<String, dynamic> json) =>
      _$DeploymentResultFromJson(json);
}

enum DeploymentStatus {
  creating,
  provisioning,
  ready,
  failed,
}