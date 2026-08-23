import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketcoder_foss/foss_app_module.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_provider_option_service.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_setup_flow.dart';

void main() {
  test('FOSS app module registers every shared app-level binding', () {
    final getIt = GetIt.asNewInstance();
    addTearDown(getIt.reset);

    FossAppModule().register(getIt);

    expect(getIt<PushService>(), isA<PushService>());
    expect(getIt<BillingService>(), isA<BillingService>());
    expect(getIt<IProviderOptionService>(), isA<IProviderOptionService>());
    expect(getIt<OnboardingSetupFlow>(), isA<OnboardingSetupFlow>());
  });
}
