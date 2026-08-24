import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_self_host_view.dart';
import 'package:url_launcher/url_launcher.dart';

const _selfHostSetupGuide =
    'https://github.com/qtpi-bonding-org/pocketcoder#quick-start';

class OnboardingSelfHostAdapter extends StatelessWidget {
  const OnboardingSelfHostAdapter({super.key});

  Future<void> _openGuide(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse(_selfHostSetupGuide),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      VimToast.show(
        context,
        context.l10n.errorCouldNotOpenBrowser,
        color: context.terminalColors.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) => OnboardingSelfHostView(
        onOpenGuide: () => _openGuide(context),
        onConnect: () => context.pushNamed(RouteNames.onboardingLogin),
      );
}
