import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/glyph_label_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_content_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class SelfHostSetupView extends StatelessWidget {
  const SelfHostSetupView({
    super.key,
    required this.onOpenGuide,
    required this.onConnect});

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
            onTap: onOpenGuide),
          TerminalAction(
            label: context.l10n.onboardingSelfHostActionConnect,
            onTap: onConnect,
            emphasis: Emphasis.outlined),
        ],
        body: OnboardingContentShell(
          child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TerminalConversationTurn(
                    speaker: TerminalConversationSpeaker.poco,
                    message: context.l10n.onboardingSelfHostPoco),
                  VSpace.x3,
                  BiosFrame(
                    title: context.l10n.onboardingSelfHostRequirementsTitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Requirement(
                          label:
                              context.l10n.onboardingSelfHostRequirementServer),
                        VSpace.x1,
                        _Requirement(
                          label:
                              context.l10n.onboardingSelfHostRequirementDocker),
                        VSpace.x1,
                        _Requirement(
                          label:
                              context.l10n.onboardingSelfHostRequirementAccess),
                      ])),
                ])));
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => GlyphLabelRow(
        glyph: '[+]',
        crossAxisAlignment: CrossAxisAlignment.start,
        child: TerminalText(
          label,
          role: TextRole.body,
        ),
      );
}
