import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app/app.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inject Pro-specific services
  await bootstrap(
    pushService: FcmPushService(),
    billingService: RevenueCatBillingService(),
  );

  runApp(const App());
}
