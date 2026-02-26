import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app/app.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inject Pro-specific services
  getIt.registerSingleton<PushService>(FcmPushService());
  getIt.registerSingleton<BillingService>(RevenueCatBillingService());

  await bootstrap();

  runApp(const App());
}
