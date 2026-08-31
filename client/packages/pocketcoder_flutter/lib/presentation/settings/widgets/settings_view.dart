import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.hasPendingMcp,
    required this.isPro,
    required this.onNavigate,
    required this.onLogout,
    required this.onFactoryReset,
    required this.onDeleteProData,
    required this.onReportAiContent,
  });

  final bool hasPendingMcp;
  final bool isPro;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;
  final VoidCallback onFactoryReset;
  final VoidCallback onDeleteProData;
  final VoidCallback onReportAiContent;

  List<(String, List<(String, String)>)> _sections(
      BuildContext context) {
    return [
      (
        context.l10n.settingsAiAgentsSection,
        [
          ('LLM MANAGEMENT', 'configureLlm'),
          ('AGENT REGISTRY', 'configureAi'),
          ('MCP MANAGEMENT', 'configureMcp'),
          ('SKILLS', 'configureSkills'),
          ('TOOL PERMISSIONS', 'configureToolPermissions'),
          ('HARNESS CONNECTIONS', 'configureHarnessAuth'),
          (context.l10n.settingsReportAiContentLabel, 'reportAiContent'),
        ]
      ),
      (
        context.l10n.settingsSystemSection,
        [
          ('SYSTEM CHECKS', 'configureSystemChecks'),
          ('POCKET MEMORY', 'configureMemory'),
          ('POCKETBASE', 'configurePocketbase'),
          ('SCHEDULER', 'configureScheduler'),
          (context.l10n.errorsTitle, 'configureErrors'),
        ]
      ),
      (
        context.l10n.settingsAccountSection,
        [
          ('NOTIFICATIONS', 'configureNotifications'),
          if (isPro) (context.l10n.proSettingsLabel, 'configurePaywall'),
          ('LOGOUT', 'logout'),
          ('RESET', 'factoryReset'),
          if (isPro)
            (context.l10n.settingsDeleteProDataLabel, 'deleteProData'),
        ]
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.settingsTitle,
      activePillar: NavPillar.configure,
      showBack: false,
      body: ListView(
        children: [
          for (final section in _sections(context))
            BiosSection(
              title: section.$1,
              centerTitle: true,
              child: Column(
                children: [
                  for (final item in section.$2)
                    BiosRow(
                      label: item.$1,
                      hasBadge: item.$2 == 'configureMcp' && hasPendingMcp,
                      isDestructive: item.$2 == 'factoryReset' ||
                          item.$2 == 'deleteProData',
                      isWarning: item.$2 == 'logout',
                      onTap: () => switch (item.$2) {
                        'logout' => onLogout(),
                        'factoryReset' => onFactoryReset(),
                        'deleteProData' => onDeleteProData(),
                        'reportAiContent' => onReportAiContent(),
                        _ => onNavigate(item.$2),
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
