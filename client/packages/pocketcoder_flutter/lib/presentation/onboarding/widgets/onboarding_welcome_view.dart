import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';

class OnboardingWelcomeView extends StatelessWidget {
  const OnboardingWelcomeView({
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
        title: context.l10n.onboardingWelcomeTitle,
        activePillar: NavPillar.configure,
        showBack: true,
        showNavigation: false,
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: AppSizes.space * 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
          ),
        ),
      );
}
