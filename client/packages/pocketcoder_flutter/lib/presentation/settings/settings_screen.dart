import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_list_tile.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import '../../app_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;

  final List<(String, String)> _options = [
    ('AGENT OBSERVABILITY', '[MANAGE]'),
    ('MCP MANAGEMENT', '[CONFIGURE]'),
    ('SOP MANAGEMENT', '[LIBRARY]'),
    ('SYSTEM CHECKS', '[DIAGNOSE]'),
    ('WHITELIST RULES', '[SETUP]'),
    ('AGENT REGISTRY', '[MODELS]'),
    ('THEME', '[PHOSPHOR GREEN]'),
    ('PERMISSION RELAY', '[STATUS]'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return TerminalScaffold(
      title: 'SYSTEM SETUP UTILITY',
      actions: [
        TerminalAction(
          label: 'EXIT',
          onTap: () => context.goNamed(RouteNames.home),
        ),
        TerminalAction(
          label: 'SAVE & EXIT',
          onTap: () => context.goNamed(RouteNames.home),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: BiosFrame(
              title: 'CONFIGURATION PARAMETERS',
              child: BlocBuilder<McpCubit, McpState>(
                builder: (context, state) {
                  final hasPendingMcp = state.maybeWhen(
                    loaded: (servers) =>
                        servers.any((s) => s.status == McpServerStatus.pending),
                    orElse: () => false,
                  );

                  return ListView.builder(
                    itemCount: _options.length,
                    itemBuilder: (context, i) {
                      final option = _options[i].$1;
                      final isMcpOption = option == 'MCP MANAGEMENT';

                      return BiosListTile(
                        label: option,
                        value: _options[i].$2,
                        isSelected: i == _selectedIndex,
                        hasBadge: isMcpOption && hasPendingMcp,
                        onTap: () {
                          setState(() => _selectedIndex = i);
                          if (option == 'AGENT OBSERVABILITY') {
                            context.pushNamed(RouteNames.agentObservability);
                          } else if (option == 'MCP MANAGEMENT') {
                            context.pushNamed(RouteNames.mcpManagement);
                          } else if (option == 'SOP MANAGEMENT') {
                            context.pushNamed(RouteNames.sopManagement);
                          } else if (option == 'SYSTEM CHECKS') {
                            context.pushNamed(RouteNames.systemChecks);
                          } else if (option == 'WHITELIST RULES') {
                            context.pushNamed(RouteNames.whitelist);
                          } else if (option == 'AGENT REGISTRY') {
                            context.pushNamed(RouteNames.aiRegistry);
                          } else if (option == 'PERMISSION RELAY') {
                            AppNavigation.toPaywall(context);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
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
      ),
    );
  }
}
