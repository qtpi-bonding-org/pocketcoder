import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_config.freezed.dart';
part 'app_config.g.dart';

@freezed
class AppConfig with _$AppConfig {
  const AppConfig._();

  const factory AppConfig({
    required String linodeClientId,
    required String linodeRedirectUri,
    required String cloudInitTemplateUrl,
    required int maxPollingAttempts,
    required int initialPollingIntervalSeconds,
  }) = _AppConfig;

  /// Linode OAuth configuration constants
  static const kLinodeClientId = String.fromEnvironment('LINODE_CLIENT_ID', defaultValue: '');
  static const kLinodeRedirectUri = 'pocketcoder://oauth-callback';

  /// Cloud-init template URL from environment or default
  static const kCloudInitTemplateUrl = String.fromEnvironment(
    'CLOUD_INIT_TEMPLATE_URL',
    defaultValue: 'https://example.com/cloud-init.yml',
  );

  /// Maximum polling attempts for deployment monitoring
  static const int kMaxPollingAttempts = 20;

  /// Initial polling interval in seconds (exponential backoff starts here)
  static const int kInitialPollingIntervalSeconds = 15;

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);
}