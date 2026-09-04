import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_logo.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_content_shell.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView(
      {super.key,
      required this.pocoState,
      required this.onLogin,
      required this.onDeploy});

  final PocoState pocoState;
  final VoidCallback onLogin;
  final VoidCallback onDeploy;

  @override
  Widget build(BuildContext context) => PocketCoderShell(
        title: null,
        activePillar: NavPillar.chats,
        showNavigation: false,
        body: OnboardingContentShell(
          paddingMultiplier: 4,
          mainAxisAlignment: MainAxisAlignment.center,
          child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AsciiLogo(
                      text: AppAscii.pocketCoderLogo),
                  VSpace.x6,
                  TerminalConversationTurn(
                    speaker: TerminalConversationSpeaker.poco,
                    message: context.l10n.onboardingNoServerPoco,
                    sequence: pocoState.sequence,
                    history: pocoState.history,
                  ),
                  VSpace.x4,
                  TerminalPromptSuggestion(
                    label: context.l10n.onboardingNoServerChipExisting,
                    onSelected: onLogin,
                  ),
                  VSpace.x1,
                  TerminalPromptSuggestion(
                    label: context.l10n.onboardingNoServerChipNew,
                    onSelected: onDeploy,
                  ),
                ],
          ),
        ),
      );
}
