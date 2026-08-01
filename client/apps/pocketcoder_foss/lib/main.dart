import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app/app.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/ntfy_push_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_billing_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_deploy_option_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FOSS build: no proprietary push/billing/deploy providers, and no
  // Aeroform/Linode provisioning wiring at all (FossDeployOptionService
  // only ever returns an external URL, never an in-app route, so nothing
  // here needs flutter_aeroform).
  getIt.registerSingleton<PushService>(NtfyPushService());
  getIt.registerSingleton<BillingService>(FossBillingService());
  getIt.registerSingleton<IDeployOptionService>(FossDeployOptionService());

  // Bootstrap registers FlutterSecureStorage, http.Client, etc., and
  // initializes the push/billing services just registered above.
  await bootstrap();

  runApp(const App());
}
