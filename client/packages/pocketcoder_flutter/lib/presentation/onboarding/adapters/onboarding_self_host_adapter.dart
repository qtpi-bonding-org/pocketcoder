import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_self_host_view.dart';
import 'package:url_launcher/url_launcher.dart';

const _selfHostSetupGuide =
    'https://github.com/qtpi-bonding-org/pocketcoder#quick-start';

class OnboardingSelfHostAdapter extends StatelessWidget {
  const OnboardingSelfHostAdapter({super.key});

  @override
  Widget build(BuildContext context) => OnboardingSelfHostView(
        onBack: () => AppNavigation.back(context),
        onOpenGuide: () => launchUrl(
          Uri.parse(_selfHostSetupGuide),
          mode: LaunchMode.externalApplication,
        ),
        onConnect: () => context.pushNamed(RouteNames.onboardingLogin),
      );
}
