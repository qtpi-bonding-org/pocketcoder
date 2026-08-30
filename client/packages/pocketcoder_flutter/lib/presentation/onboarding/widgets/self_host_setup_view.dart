import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class SelfHostSetupView extends StatelessWidget {
  const SelfHostSetupView({
    super.key,
    required this.onOpenGuide,
    required this.onConnect,
  });

  final VoidCallback onOpenGuide;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => PocketCoderShell(
        title: context.l10n.onboardingSelfHostTitle,
        activePillar: NavPillar.configure,
        showBack: true,
        backFallbackRoute: AppRoutes.onboarding,
        actions: [
          TerminalAction(
            label: context.l10n.onboardingSelfHostActionGuide,
            onTap: onOpenGuide,
          ),
          TerminalAction(
            label: context.l10n.onboardingSelfHostActionConnect,
            onTap: onConnect,
            emphasis: Emphasis.outlined,
          ),
        ],
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
                    message: context.l10n.onboardingSelfHostPoco,
                  ),
                  VSpace.x3,
                  BiosFrame(
                    title: context.l10n.onboardingSelfHostRequirementsTitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Requirement(
                          label:
                              context.l10n.onboardingSelfHostRequirementServer,
                        ),
                        VSpace.x1,
                        _Requirement(
                          label:
                              context.l10n.onboardingSelfHostRequirementDocker,
                        ),
                        VSpace.x1,
                        _Requirement(
                          label:
                              context.l10n.onboardingSelfHostRequirementAccess,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TerminalText.label('[+]'),
          HSpace.x1,
          Expanded(child: TerminalText(label)),
        ],
      );
}
