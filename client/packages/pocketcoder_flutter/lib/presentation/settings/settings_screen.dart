import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_list_tile.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import '../../app_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;

  // Grouped configuration sections
  static const _sections = <(String, List<(String, String, String)>)>[
    ('AI & AGENTS', [
      ('AGENT REGISTRY', '[MODELS]', 'configureAi'),
    ]),
    ('SECURITY', [
      ('TOOL PERMISSIONS', '[SETUP]', 'configureWhitelist'),
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
    final colors = context.colorScheme;
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

          int flatIndex = 0;
          return ListView(
            children: [
              for (final section in _sections) ...[
                BiosSection(
                  title: section.$1,
                  child: Column(
                    children: [
                      for (final item in section.$2)
                        Builder(builder: (context) {
                          final myIndex = flatIndex++;
                          final isMcp = item.$3 == 'configureMcp';
                          return BiosListTile(
                            label: item.$1,
                            value: item.$2,
                            isSelected: myIndex == _selectedIndex,
                            hasBadge: isMcp && hasPendingMcp,
                            onTap: () {
                              setState(() => _selectedIndex = myIndex);
                              _navigateTo(context, item.$3);
                            },
                          );
                        }),
                    ],
                  ),
                ),
              ],
              VSpace.x2,
              Padding(
                padding: EdgeInsets.all(AppSizes.space),
                child: Text(
                  'Use ARROW KEYS to navigate.\nPress ENTER to change value.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: colors.onSurface.withValues(alpha: 0.7),
                    fontSize: AppSizes.fontTiny,
                    package: 'pocketcoder_flutter',
                  ),
                ),
              ),
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
      case 'configureWhitelist':
        context.push(AppRoutes.configureWhitelist);
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
    }
  }
}
