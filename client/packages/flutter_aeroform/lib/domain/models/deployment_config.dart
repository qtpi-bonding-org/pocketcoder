import 'package:freezed_annotation/freezed_annotation.dart';

part 'deployment_config.freezed.dart';
part 'deployment_config.g.dart';

@freezed
class DeploymentConfig with _$DeploymentConfig {
  const DeploymentConfig._();

  const factory DeploymentConfig({
    required String planType,
    required String region,
    required String adminEmail,
    required String geminiApiKey,
    String? linodeToken,
    required bool ntfyEnabled,
    required String cloudInitTemplateUrl,
  }) = _DeploymentConfig;

  Map<String, String> toMetadata() {
    return {
      'admin_email': adminEmail,
      'gemini_api_key': geminiApiKey,
      'ntfy_enabled': ntfyEnabled.toString(),
      if (linodeToken != null) 'linode_token': linodeToken!,
    };
  }

  factory DeploymentConfig.fromJson(Map<String, dynamic> json) =>
      _$DeploymentConfigFromJson(json);
}