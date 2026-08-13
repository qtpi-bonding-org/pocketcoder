import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';

/// App-level continuation for the shared onboarding welcome screen.
///
/// The public app offers the self-hosted path. Commercial distributions can
/// inject a guided setup implementation without teaching shared onboarding
/// screens about billing or cloud providers.
abstract interface class OnboardingSetupFlow {
  bool get offersGuidedSetup;

  Future<void> startGuidedSetup(BuildContext context);

  void showSelfHostInformation(BuildContext context);
}

class SelfHostedOnboardingSetupFlow implements OnboardingSetupFlow {
  const SelfHostedOnboardingSetupFlow();

  @override
  bool get offersGuidedSetup => false;

  @override
  Future<void> startGuidedSetup(BuildContext context) async {
    showSelfHostInformation(context);
  }

  @override
  void showSelfHostInformation(BuildContext context) {
    context.pushNamed(RouteNames.onboardingSelfHost);
  }
}
