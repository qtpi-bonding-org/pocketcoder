import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/decision_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/glyph_label_row.dart';
import 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_content_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class SelfHostSetupView extends StatelessWidget {
  const SelfHostSetupView(
      {super.key, required this.onOpenGuide, required this.onConnect});

  final VoidCallback onOpenGuide;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => PocketCoderShell(
      showBack: true,
      backFallbackRoute: AppRoutes.onboarding,
      footer: WizardFooter(step: 5, totalSteps: 6, onNext: onConnect),
      body: OnboardingContentShell(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeader(name: context.l10n.onboardingSelfHostTitle.toLowerCase()),
        TerminalConversationTurn(
            speaker: TerminalConversationSpeaker.poco,
            message: context.l10n.onboardingSelfHostPoco),
        VSpace.x3,
        DecisionFrame(
            title:
                context.l10n.onboardingSelfHostRequirementsTitle.toLowerCase(),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Requirement(
                      label: context.l10n.onboardingSelfHostRequirementServer),
                  VSpace.x1,
                  _Requirement(
                      label: context.l10n.onboardingSelfHostRequirementDocker),
                  VSpace.x1,
                  _Requirement(
                      label: context.l10n.onboardingSelfHostRequirementAccess),
                ])),
        VSpace.x3,
        TerminalButton(
            label: context.l10n.onboardingSelfHostActionGuide,
            kind: ActionKind.neutral,
            onTap: onOpenGuide),
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
