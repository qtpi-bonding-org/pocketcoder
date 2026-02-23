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
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await bootstrap(
    pushService: LocalPushService(),
    billingService: LocalBillingService(),
  );

  runApp(const App());
}
