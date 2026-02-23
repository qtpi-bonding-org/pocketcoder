import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app/app.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:foss/foss.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inject FOSS-specific services
  await bootstrap(
    pushService: NtfyPushService(),
    billingService: FossBillingService(),
  );

  runApp(const App());
}
