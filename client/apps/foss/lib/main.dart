import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app/app.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/ntfy_push_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_billing_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inject FOSS-specific services (Now from core)
  getIt.registerSingleton<PushService>(NtfyPushService());
  getIt.registerSingleton<BillingService>(FossBillingService());

  await bootstrap();

  runApp(const App());
}
