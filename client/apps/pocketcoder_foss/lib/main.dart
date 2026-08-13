import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app/app.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/ntfy_push_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_billing_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_deploy_option_service.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_setup_flow.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FOSS build: use the open push, billing, and deployment providers.
  // FossDeployOptionService opens the inspectable self-hosting flow rather
  // than routing to a managed in-app provisioner.
  getIt.registerSingleton<PushService>(NtfyPushService());
  getIt.registerSingleton<BillingService>(FossBillingService());
  getIt.registerSingleton<IDeployOptionService>(FossDeployOptionService());
  getIt.registerSingleton<OnboardingSetupFlow>(
    const SelfHostedOnboardingSetupFlow(),
  );

  // Bootstrap registers FlutterSecureStorage, http.Client, etc., and
  // initializes the push/billing services just registered above.
  await bootstrap();

  runApp(const App());
}
