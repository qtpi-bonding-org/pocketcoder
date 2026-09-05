import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_content_shell.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({
    super.key,
    required this.showGuidedSetup,
    required this.onGuidedSetup,
    required this.onSelfHost,
  });

  final bool showGuidedSetup;
  final VoidCallback onGuidedSetup;
  final VoidCallback onSelfHost;

  @override
  Widget build(BuildContext context) => PocketCoderShell(
        showBack: true,
        backFallbackRoute: AppRoutes.onboarding,
        // Counted so the flow stays contiguous 1..6 -- but no onNext:
        // the two prompts in the body are the choice, and a footer
        // <next> would silently pick one of them.
        footer: const WizardFooter(step: 1, totalSteps: 6),
        body: OnboardingContentShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                  name: context.l10n.onboardingWelcomeTitle.toLowerCase()),
              TerminalConversationTurn(
                speaker: TerminalConversationSpeaker.poco,
                message: context.l10n.onboardingWelcomePoco,
              ),
              VSpace.x3,
              if (showGuidedSetup) ...[
                TerminalPromptSuggestion(
                  label: context.l10n.onboardingWelcomeActionGuided,
                  onSelected: onGuidedSetup,
                  emphasis: Emphasis.outlined,
                ),
                VSpace.x1,
              ],
              TerminalPromptSuggestion(
                label: context.l10n.onboardingWelcomeActionSelfHost,
                onSelected: onSelfHost,
              ),
            ],
          ),
        ),
      );
}
