import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_list_tile.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.hasPendingMcp,
    required this.onNavigate,
    required this.onLogout,
  });

  final bool hasPendingMcp;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  List<(String, List<(String, String, String)>)> _sections(
      BuildContext context) {
    return [
      (
        context.l10n.settingsAiAgentsSection,
        [
          ('LLM MANAGEMENT', '[KEYS]', 'configureLlm'),
          ('AGENT REGISTRY', '[MODELS]', 'configureAi'),
        ]
      ),
      (
        context.l10n.settingsSecuritySection,
        [
          ('TOOL PERMISSIONS', '[SETUP]', 'configureToolPermissions'),
          ('HARNESS CONNECTIONS', '[CONFIGURE]', 'configureHarnessAuth'),
          ('MCP MANAGEMENT', '[CONFIGURE]', 'configureMcp'),
          ('SKILLS', '[MANAGE]', 'configureSkills'),
        ]
      ),
      (
        context.l10n.settingsSystemSection,
        [
          ('SYSTEM CHECKS', '[DIAGNOSE]', 'configureSystemChecks'),
          (
            context.l10n.proSettingsLabel,
            context.l10n.proSettingsStatus,
            'configurePaywall',
          ),
          (
            context.l10n.pocketCoderUpdateTitle,
            '[UPDATE]',
            'serverControls',
          ),
          (context.l10n.errorsTitle, '[VIEW]', 'configureErrors'),
        ]
      ),
      (
        context.l10n.settingsObservabilitySection,
        [
          ('AGENT OBSERVABILITY', '[MANAGE]', 'configureObservability'),
        ]
      ),
      (
        context.l10n.settingsAutomationSection,
        [
          ('SCHEDULER', '[MANAGE]', 'configureScheduler'),
        ]
      ),
      (
        context.l10n.settingsAccountSection,
        [
          ('NOTIFICATIONS', '[CONFIGURE]', 'configureNotifications'),
          ('LOGOUT', '[SIGN OUT]', 'logout'),
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
              child: Column(
                children: [
                  for (final item in section.$2)
                    BiosListTile(
                      label: item.$1,
                      value: item.$2,
                      hasBadge: item.$3 == 'configureMcp' && hasPendingMcp,
                      isDestructive: item.$3 == 'logout',
                      onTap: () => item.$3 == 'logout'
                          ? onLogout()
                          : onNavigate(item.$3),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
