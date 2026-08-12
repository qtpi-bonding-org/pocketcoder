import 'dart:async';
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'app/bootstrap.dart';
import 'domain/notifications/push_service.dart';
import 'domain/billing/billing_service.dart';
import 'domain/deployment/i_deploy_option_service.dart';
import 'infrastructure/foss/foss_deploy_option_service.dart';

class LocalPushService implements PushService {
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> getToken() async => "local_token";
  @override
  Stream<PushNotificationPayload> get notificationStream =>
      const Stream.empty();
  @override
  Future<PushNotificationPayload?> getInitialNotification() async => null;
  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> configure() async {}
}

class LocalBillingService implements BillingService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> identify(String userId) async {}
  @override
  Future<void> reset() async {}
  @override
  Future<bool> hasProAccess() async => true;
  @override
  Future<void> restorePurchases() async {}
  @override
  Future<bool> purchasePro(String identifier) async => true;
  @override
  Future<BillingPackage?> getProPackage() async => null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-register services so Injection can pick them up
  getIt.registerSingleton<PushService>(LocalPushService());
  getIt.registerSingleton<BillingService>(LocalBillingService());
  getIt.registerSingleton<IDeployOptionService>(FossDeployOptionService());

  await bootstrap();

  runApp(const App());
}
