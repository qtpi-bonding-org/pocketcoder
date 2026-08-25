import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class AgentAuthView extends StatelessWidget {
  const AgentAuthView({
    super.key,
    required this.status,
    required this.harnesses,
    required this.error,
    required this.onSelected,
  });

  final UiFlowStatus status;
  final List<Harnesse> harnesses;
  final Object? error;
  final ValueChanged<Harnesse> onSelected;

  @override
  Widget build(BuildContext context) {
    final supported = harnesses.where((harness) {
      final cli = harness.cliId.trim().toLowerCase();
      return cli == 'claude-code' || cli == 'codex';
    }).toList();

    return PocketCoderShell(
      title: context.l10n.onboardingChooseHarnessTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: _buildBody(context, supported),
    );
  }

  Widget _buildBody(BuildContext context, List<Harnesse> supported) {
    if (status == UiFlowStatus.loading && supported.isEmpty) {
      return const Center(child: TerminalLoadingIndicator());
    }
    if (status == UiFlowStatus.failure && supported.isEmpty) {
      // Never surfaces `error`'s raw text -- it may carry an unpredictable
      // underlying exception that client/AGENTS.md requires stay out of
      // user-facing copy.
      return Center(
        child: TerminalText(
          context.l10n.errorGeneric,
          color: context.terminalColors.warning,
          textAlign: TextAlign.center,
        ),
      );
    }
    if (supported.isEmpty) {
      return Center(child: TerminalText(context.l10n.errorGeneric));
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.all(AppSizes.space * 2),
          children: [
            TerminalText(
              context.l10n.onboardingChooseHarnessBody,
              alpha: 0.7,
            ),
            VSpace.x3,
            for (final harness in supported)
              Padding(
                padding: EdgeInsets.only(bottom: AppSizes.space),
                child: _HarnessChoiceCard(
                  harness: harness,
                  onTap: () => onSelected(harness),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HarnessChoiceCard extends StatelessWidget {
  const _HarnessChoiceCard({required this.harness, required this.onTap});

  final Harnesse harness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return InkWell(
      onTap: onTap,
      child: TerminalCard(
        child: Row(
          children: [
            TerminalText.label(r'$', color: colors.primary),
            HSpace.x2,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    harness.name,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontFamily: AppFonts.headerFamily,
                      fontSize: AppSizes.fontStandard,
                      fontWeight: AppFonts.heavy,
                    ),
                  ),
                  VSpace.x1,
                  TerminalText(
                    harness.cliId.toLowerCase() == 'codex'
                        ? context.l10n.onboardingCodexAccountLogin
                        : context.l10n.onboardingClaudeAccountLogin,
                    alpha: 0.6,
                  ),
                ],
              ),
            ),
            Text('[>]', style: TextStyle(color: colors.primary)),
          ],
        ),
      ),
    );
  }
}
