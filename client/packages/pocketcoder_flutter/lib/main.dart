import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'application/boot/boot_routing_decider.dart';
import 'app/app_dependency_module.dart';
import 'domain/notifications/push_service.dart';
import 'domain/billing/billing_service.dart';
import 'domain/deployment/i_provider_option_service.dart';
import 'infrastructure/foss/foss_provider_option_service.dart';
import 'presentation/onboarding/onboarding_setup_flow.dart';

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
  Future<void> syncAuthenticatedDevice() async {}
  @override
  Future<void> unregisterAuthenticatedDevice() async {}

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
  Future<void> manageSubscription() async {}
  @override
  Future<bool> purchasePro(String identifier) async => true;
  @override
  Future<BillingPackage?> getProPackage() async => null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await bootstrap(appModule: LocalAppModule());

  runApp(const App());
  await getIt<BootRoutingDecider>().start();
}

/// Local composition used by the shared package's development entry point.
class LocalAppModule implements AppDependencyModule {
  @override
  void register(GetIt getIt) {
    getIt.registerSingleton<PushService>(LocalPushService());
    getIt.registerSingleton<BillingService>(LocalBillingService());
    getIt
        .registerSingleton<IProviderOptionService>(FossProviderOptionService());
    getIt.registerSingleton<OnboardingSetupFlow>(
      const SelfHostedOnboardingSetupFlow(),
    );
  }
}
