import 'dart:async';
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'app/bootstrap.dart';
import 'domain/notifications/push_service.dart';
import 'domain/billing/billing_service.dart';

class LocalPushService implements PushService {
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> getToken() async => "local_token";
  @override
  Stream<PushNotificationPayload> get notificationStream =>
      const Stream.empty();
  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> configure() async {}
}

class LocalBillingService implements BillingService {
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isPremium() async => true;
  @override
  Future<void> restorePurchases() async {}
  @override
  Future<bool> purchase(String identifier) async => true;
  @override
  Future<List<BillingPackage>> getAvailablePackages() async {
    return [
      const BillingPackage(
        identifier: 'local_premium',
        title: 'Local Premium',
        description: 'Mock premium package for local development.',
        priceString: r'$13.37',
      ),
    ];
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-register services so Injection can pick them up
  getIt.registerSingleton<PushService>(LocalPushService());
  getIt.registerSingleton<BillingService>(LocalBillingService());

  await bootstrap();

  runApp(const App());
}
