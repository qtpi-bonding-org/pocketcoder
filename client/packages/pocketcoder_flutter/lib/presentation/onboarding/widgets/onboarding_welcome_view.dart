import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';

class OnboardingWelcomeView extends StatelessWidget {
  const OnboardingWelcomeView({
    super.key,
    required this.onBack,
    required this.showGuidedSetup,
    required this.onGuidedSetup,
    required this.onSelfHost,
  });

  final VoidCallback onBack;
  final bool showGuidedSetup;
  final VoidCallback onGuidedSetup;
  final VoidCallback onSelfHost;

  @override
  Widget build(BuildContext context) => TerminalScaffold(
        title: context.l10n.onboardingWelcomeTitle,
        actions: [
          TerminalAction(label: context.l10n.actionBack, onTap: onBack),
        ],
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: AppSizes.space * 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PocoBubble(
                    message: context.l10n.onboardingWelcomePoco,
                    pocoSize: AppSizes.fontLarge,
                  ),
                  VSpace.x3,
                  if (showGuidedSetup) ...[
                    TerminalPromptSuggestion(
                      label: context.l10n.onboardingWelcomeActionGuided,
                      onSelected: onGuidedSetup,
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
