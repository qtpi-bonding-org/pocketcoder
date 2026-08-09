import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_logo.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key, required this.pocoState, required this.onLogin, required this.onDeploy});

  final PocoState pocoState;
  final VoidCallback onLogin;
  final VoidCallback onDeploy;

  @override
  Widget build(BuildContext context) => TerminalScaffold(
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
                  AsciiLogo(text: AppAscii.pocketCoderLogo, fontSize: AppSizes.fontTiny),
                  VSpace.x6,
                  PocoBubble(message: pocoState.message, sequence: pocoState.sequence, history: pocoState.history, pocoSize: AppSizes.fontLarge),
                  VSpace.x4,
                  TerminalText(context.l10n.onboardingConnectOrDeploy, alpha: 0.7),
                  VSpace.x4,
                  Row(children: [
                    Expanded(child: _Choice(label: context.l10n.onboardingLogin, description: context.l10n.onboardingExistingServer, onTap: onLogin)),
                    HSpace.x2,
                    Expanded(child: _Choice(label: context.l10n.onboardingDeploy, description: context.l10n.onboardingCreateServer, onTap: onDeploy)),
                  ]),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.description, required this.onTap});
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
        decoration: BoxDecoration(border: Border.all(color: colors.primary.withValues(alpha: 0.7))),
        child: Column(children: [
          Text(label, style: TextStyle(color: colors.primary, fontFamily: AppFonts.headerFamily, fontSize: AppSizes.fontStandard, fontWeight: AppFonts.heavy)),
          VSpace.x1,
          TerminalText.tiny(description, alpha: 0.6),
        ]),
      ),
    );
  }
}
