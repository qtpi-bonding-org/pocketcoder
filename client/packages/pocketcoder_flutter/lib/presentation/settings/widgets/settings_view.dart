import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/nav_banner.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.hasPendingMcp,
    required this.isPro,
    required this.hapticsEnabled,
    required this.onNavigate,
    required this.onLogout,
    required this.onFactoryReset,
    required this.onDeleteProData,
    required this.onReportAiContent,
    required this.onHapticsChanged,
  });

  final bool hasPendingMcp;
  final bool isPro;
  final bool hapticsEnabled;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;
  final VoidCallback onFactoryReset;
  final VoidCallback onDeleteProData;
  final VoidCallback onReportAiContent;
  final ValueChanged<bool> onHapticsChanged;

  List<(String, List<(String, String)>)> _sections(BuildContext context) {
    return [
      (
        context.l10n.settingsAiAgentsSection,
        [
          (context.l10n.settingsMenuLlmManagement, 'configureLlm'),
          (context.l10n.settingsMenuAgentRegistry, 'configureAi'),
          (context.l10n.settingsMenuMcpManagement, 'configureMcp'),
          (context.l10n.settingsMenuSkills, 'configureSkills'),
          (
            context.l10n.settingsMenuToolPermissions,
            'configureToolPermissions'
          ),
          (context.l10n.settingsMenuHarnessConnections, 'configureHarnessAuth'),
          (context.l10n.settingsReportAiContentLabel, 'reportAiContent'),
        ]
      ),
      (
        context.l10n.settingsSystemSection,
        [
          (context.l10n.settingsMenuSystemChecks, 'statusSystemChecks'),
          (context.l10n.settingsMenuPocketMemory, 'statusMemory'),
          (context.l10n.settingsMenuPocketbase, 'statusPocketbase'),
          (context.l10n.settingsMenuScheduler, 'configureScheduler'),
          (context.l10n.errorsTitle, 'statusErrors'),
        ]
      ),
      (
        context.l10n.settingsAccountSection,
        [
          (context.l10n.settingsMenuNotifications, 'configureNotifications'),
          if (isPro) (context.l10n.proSettingsLabel, 'configurePaywall'),
          (context.l10n.settingsMenuLogout, 'logout'),
          (context.l10n.settingsMenuReset, 'factoryReset'),
          if (isPro) (context.l10n.settingsDeleteProDataLabel, 'deleteProData'),
        ]
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      footer: buildPillarFooter(context, NavPillar.config),
      showBack: false,
      body: ListView(
        children: [
          NavBanner(pillar: NavPillar.config),
          for (final section in _sections(context)) ...[
            SectionHeader(name: section.$1.toLowerCase()),
            Column(
              children: [
                for (final item in section.$2)
                  DetailRow(
                    label: item.$1,
                    hasBadge: item.$2 == 'configureMcp' && hasPendingMcp,
                    destructive:
                        item.$2 == 'factoryReset' || item.$2 == 'deleteProData',
                    warning: item.$2 == 'logout',
                    affordance: RowAffordance.navigate,
                    onTap: () => switch (item.$2) {
                      'logout' => onLogout(),
                      'factoryReset' => onFactoryReset(),
                      'deleteProData' => onDeleteProData(),
                      'reportAiContent' => onReportAiContent(),
                      _ => onNavigate(item.$2),
                    },
                  ),
                if (section.$1 == context.l10n.settingsSystemSection)
                  DetailRow.toggle(
                    label: context.l10n.settingsMenuHapticFeedback,
                    value: hapticsEnabled,
                    onChanged: onHapticsChanged,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
