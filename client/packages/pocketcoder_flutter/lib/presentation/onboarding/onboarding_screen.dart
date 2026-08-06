import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_logo.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_widget.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_login_screen.dart';

/// Entry point for the one-time server setup funnel.
///
/// The page only chooses a path. Each subsequent step owns its own form or
/// operation state, so returning from a later step never rebuilds a partially
/// filled login/deploy form.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.prefill});

  final OnboardingPrefill? prefill;

  @override
  Widget build(BuildContext context) {
    if (prefill != null) {
      return OnboardingLoginScreen(prefill: prefill);
    }

    return TerminalScaffold(
      title: context.l10n.onboardingSetupTitle,
      showHeader: false,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: AppSizes.space * 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AsciiLogo(
                  text: AppAscii.pocketCoderLogo,
                  fontSize: AppSizes.fontTiny,
                ),
                VSpace.x6,
                PocoWidget(pocoSize: AppSizes.fontLarge),
                VSpace.x4,
                TerminalText(
                  context.l10n.onboardingConnectOrDeploy,
                  alpha: 0.7,
                ),
                VSpace.x4,
                Row(
                  children: [
                    Expanded(
                      child: _OnboardingChoice(
                        label: context.l10n.onboardingLogin,
                        description: context.l10n.onboardingExistingServer,
                        onTap: () => context.pushNamed(
                          RouteNames.onboardingLogin,
                        ),
                      ),
                    ),
                    HSpace.x2,
                    Expanded(
                      child: _OnboardingChoice(
                        label: context.l10n.onboardingDeploy,
                        description: context.l10n.onboardingCreateServer,
                        onTap: () => context.pushNamed(
                          RouteNames.onboardingDeploy,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingChoice extends StatelessWidget {
  const _OnboardingChoice({
    required this.label,
    required this.description,
    required this.onTap,
  });

  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSizes.space * 1.5),
        decoration: BoxDecoration(
          border: Border.all(color: colors.primary.withValues(alpha: 0.7)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: colors.primary,
                fontFamily: AppFonts.headerFamily,
                fontSize: AppSizes.fontStandard,
                fontWeight: AppFonts.heavy,
              ),
            ),
            VSpace.x1,
            TerminalText.tiny(description, alpha: 0.6),
          ],
        ),
      ),
    );
  }
}
