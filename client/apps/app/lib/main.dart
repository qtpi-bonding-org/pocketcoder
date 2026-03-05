import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app/app.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inject Pro-specific services (before bootstrap)
  getIt.registerSingleton<PushService>(FcmPushService());
  getIt.registerSingleton<BillingService>(RevenueCatBillingService());
  getIt.registerSingleton<IDeployOptionService>(ProDeployOptionService());

  // Pre-register aeroform config (AppConfig, linodeClientId)
  preRegisterAeroformConfig();

  // Inject Linode deployment routes before router is accessed
  AppRouter.setAdditionalRoutes(linodeRoutes);

  // Bootstrap registers FlutterSecureStorage, http.Client, etc.
  await bootstrap();

  // Now initialize aeroform DI (depends on FlutterSecureStorage, http.Client)
  initializeAeroformDI();

  runApp(const App());
}
