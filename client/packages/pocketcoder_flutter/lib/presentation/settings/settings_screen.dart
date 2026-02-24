import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../design_system/theme/app_theme.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/bios_frame.dart';
import '../core/widgets/bios_list_tile.dart';
import '../core/widgets/terminal_header.dart';
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
    ('PUSH NOTIFICATIONS', '[STATUS]'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: ScanlineWidget(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSizes.space * 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TerminalHeader(title: 'SYSTEM SETUP UTILITY'),
                VSpace.x3,
                Expanded(
                  child: BiosFrame(
                    title: 'CONFIGURATION PARAMETERS',
                    child: ListView.builder(
                      itemCount: _options.length,
                      itemBuilder: (context, i) {
                        return BiosListTile(
                          label: _options[i].$1,
                          value: _options[i].$2,
                          isSelected: i == _selectedIndex,
                          onTap: () {
                            setState(() => _selectedIndex = i);
                            final option = _options[i].$1;
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
                            } else if (option == 'PUSH NOTIFICATIONS') {
                              AppNavigation.toPaywall(context);
                            }
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
          ),
        ),
      ),
      bottomNavigationBar: TerminalFooter(
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
      ),
    );
  }
}
