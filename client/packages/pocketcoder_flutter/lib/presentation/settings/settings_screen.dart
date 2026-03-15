import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_list_tile.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import '../../app_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _sections = <(String, List<(String, String, String)>)>[
    ('AI & AGENTS', [
      ('LLM MANAGEMENT', '[KEYS]', 'configureLlm'),
      ('AGENT REGISTRY', '[MODELS]', 'configureAi'),
    ]),
    ('SECURITY', [
      ('TOOL PERMISSIONS', '[SETUP]', 'configureToolPermissions'),
      ('MCP MANAGEMENT', '[CONFIGURE]', 'configureMcp'),
    ]),
    ('GOVERNANCE', [
      ('SOP MANAGEMENT', '[LIBRARY]', 'configureSop'),
    ]),
    ('SYSTEM', [
      ('SYSTEM CHECKS', '[DIAGNOSE]', 'configureSystemChecks'),
      ('PERMISSION RELAY', '[STATUS]', 'configurePaywall'),
    ]),
    ('OBSERVABILITY', [
      ('AGENT OBSERVABILITY', '[MANAGE]', 'configureObservability'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: 'CONFIGURE',
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
              for (final section in _sections) ...[
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
