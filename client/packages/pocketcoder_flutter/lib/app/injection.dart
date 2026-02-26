import 'package:flutter_aeroform/domain/models/app_config.dart';
import 'bootstrap.dart';



/// Configures dependencies for widget/integration tests.
///
/// This sets up the DI container with mock implementations
/// suitable for UI testing.
Future<void> configureTestDependencies() async {
  // Reset any existing registrations
  if (getIt.isRegistered<AppConfig>()) {
    getIt.unregister<AppConfig>();
  }

  // Register test configuration
  getIt.registerSingleton<AppConfig>(
    const AppConfig(
      linodeClientId: 'test-client-id',
      linodeRedirectUri: 'pocketcoder://oauth-callback',
      cloudInitTemplateUrl: 'https://example.com/cloud-init',
      maxPollingAttempts: 20,
      initialPollingIntervalSeconds: 15,
    ),
  );
}