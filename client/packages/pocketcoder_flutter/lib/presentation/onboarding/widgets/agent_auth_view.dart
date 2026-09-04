import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/harness_choice_card.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_content_shell.dart';

class AgentAuthView extends StatelessWidget {
  const AgentAuthView({
    super.key,
    required this.status,
    required this.harnesses,
    required this.error,
    required this.onSelected,
    required this.harnessProvidersLoaded,
    required this.onSkip,
    this.onContinue,
    this.connectedHarnessIds = const {},
    this.selectedHarnesses = const []});

  final UiFlowStatus status;
  final List<Harnesse> harnesses;
  final Object? error;
  final ValueChanged<Harnesse> onSelected;
  final bool harnessProvidersLoaded;

  /// Always available: connecting a harness is optional up front, so the
  /// user can reach chats without ever picking one.
  final VoidCallback onSkip;

  /// Null until at least one harness is connected -- lets someone connect
  /// more than one before moving on, instead of auto-navigating to chat
  /// the moment the first one succeeds.
  final VoidCallback? onContinue;

  final Set<String> connectedHarnessIds;

  /// The harness cli_ids chosen for this deployment during initial
  /// provisioning (server/pocketbase's getReleaseStatus, sourced from
  /// release-manager's current.json). Falls back to the original
  /// claude-code/codex-only allowlist when empty -- either this is an older
  /// deployment predating this field, or ReleaseStatusCubit hasn't loaded
  /// yet.
  final List<String> selectedHarnesses;

  @override
  Widget build(BuildContext context) {
    final allowlist = selectedHarnesses.isNotEmpty
        ? selectedHarnesses.map((id) => id.trim().toLowerCase()).toSet()
        : {'claude-code', 'codex'};
    final supported = harnesses.where((harness) {
      final cli = harness.cliId.trim().toLowerCase();
      return allowlist.contains(cli);
    }).toList();

    return PocketCoderShell(
      title: context.l10n.onboardingChooseHarnessTitle,
      activePillar: NavPillar.configure,
      showBack: false,
      showNavigation: false,
      actions: [
        TerminalAction(label: context.l10n.actionSkip, onTap: onSkip),
        if (onContinue case final continueTap?)
          TerminalAction(
            label: context.l10n.actionContinue,
            onTap: continueTap,
            emphasis: Emphasis.outlined),
      ],
      body: _buildBody(context, supported));
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
          role: TextRole.warn,
        ),
      );
    }
    if (supported.isEmpty) {
      return Center(
        child: TerminalText(
          context.l10n.errorGeneric,
          role: TextRole.body,
        ),
      );
    }

    return OnboardingContentShell(
      listBuilder: (context) => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.all(AppSizes.space * 2),
        children: [
          TerminalText(
            context.l10n.onboardingChooseHarnessBody,
            role: TextRole.body,
          ),
          VSpace.x3,
          if (!harnessProvidersLoaded)
            TerminalText(context.l10n.onboardingChooseHarnessLoadingProviders, role: TextRole.body),
          for (final harness in supported)
            Padding(
              padding: EdgeInsets.only(bottom: AppSizes.space),
              child: HarnessChoiceCard(
                harness: harness,
                connected: connectedHarnessIds.contains(harness.id),
                onTap:
                    harnessProvidersLoaded ? () => onSelected(harness) : null)),
        ]));
  }
}
