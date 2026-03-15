import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_list_tile.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import '../../app_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static List<(String, List<(String, String, String)>)> _sections(
      BuildContext context) {
    return [
      (context.l10n.settingsAiAgentsSection, [
        ('LLM MANAGEMENT', '[KEYS]', 'configureLlm'),
        ('AGENT REGISTRY', '[MODELS]', 'configureAi'),
      ]),
      (context.l10n.settingsSecuritySection, [
        ('TOOL PERMISSIONS', '[SETUP]', 'configureToolPermissions'),
        ('MCP MANAGEMENT', '[CONFIGURE]', 'configureMcp'),
      ]),
      (context.l10n.settingsGovernanceSection, [
        ('SOP MANAGEMENT', '[LIBRARY]', 'configureSop'),
      ]),
      (context.l10n.settingsSystemSection, [
        ('SYSTEM CHECKS', '[DIAGNOSE]', 'configureSystemChecks'),
        ('PERMISSION RELAY', '[STATUS]', 'configurePaywall'),
      ]),
      (context.l10n.settingsObservabilitySection, [
        ('AGENT OBSERVABILITY', '[MANAGE]', 'configureObservability'),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.settingsTitle,
      activePillar: NavPillar.configure,
      showBack: false,
      body: BlocBuilder<McpCubit, McpState>(
        builder: (context, state) {
          final hasPendingMcp = state.maybeWhen(
            loaded: (servers) =>
                servers.any((s) => s.status == McpServerStatus.pending),
            orElse: () => false,
          );

          return ListView(
            children: [
              for (final section in _sections(context)) ...[
                BiosSection(
                  title: section.$1,
                  child: Column(
                    children: [
                      for (final item in section.$2)
                        Builder(builder: (context) {
                          final isMcp = item.$3 == 'configureMcp';
                          return BiosListTile(
                            label: item.$1,
                            value: item.$2,
                            hasBadge: isMcp && hasPendingMcp,
                            onTap: () {
                              _navigateTo(context, item.$3);
                            },
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _navigateTo(BuildContext context, String routeKey) {
    switch (routeKey) {
      case 'configureAi':
        context.push(AppRoutes.configureAi);
      case 'configureToolPermissions':
        context.push(AppRoutes.configureToolPermissions);
      case 'configureMcp':
        context.push(AppRoutes.configureMcp);
      case 'configureSop':
        context.push(AppRoutes.configureSop);
      case 'configureSystemChecks':
        context.push(AppRoutes.configureSystemChecks);
      case 'configurePaywall':
        context.push(AppRoutes.configurePaywall);
      case 'configureObservability':
        context.push(AppRoutes.configureObservability);
      case 'configureLlm':
        context.push(AppRoutes.configureLlm);
    }
  }
}
