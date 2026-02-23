import 'package:flutter/material.dart';
import 'app/app.dart';
import 'app/bootstrap.dart';
import 'domain/notifications/mock_push_service.dart';
import 'domain/billing/foss_billing_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await bootstrap(
    pushService: MockPushService(),
    billingService: FossBillingService(),
  );

  runApp(const App());
}
