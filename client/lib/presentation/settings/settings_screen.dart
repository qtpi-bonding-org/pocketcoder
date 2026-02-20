import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../design_system/theme/app_theme.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/bios_frame.dart';
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
    ('MCP MANAGEMENT', '[EQUIP]'),
    ('SOP MANAGEMENT', '[LIBRARY]'),
    ('SYSTEM CHECKS', '[DIAGNOSE]'),
    ('WHITELIST RULES', '[SETUP]'),
    ('AI REGISTRY', '[MODELS]'),
    ('THEME', '[CYBERPUNK]'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: ScanlineWidget(
        child: SafeArea(
          child: Center(
            child: BiosFrame(
              title: 'SYSTEM SETUP UTILITY',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < _options.length; i++)
                    _buildBiosOption(
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
                        } else if (option == 'AI REGISTRY') {
                          context.pushNamed(RouteNames.aiRegistry);
                        }
                      },
                    ),
                  VSpace.x2,
                  Text(
                    'Use ARROW KEYS to navigate.\nPress ENTER to change value.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: colors.onSurface,
                      fontSize: AppSizes.fontMini,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: TerminalFooter(
        actions: [
          TerminalAction(
            keyLabel: 'ESC',
            label: 'EXIT',
            onTap: () => context.goNamed(RouteNames.home),
          ),
          TerminalAction(
            keyLabel: 'F10',
            label: 'SAVE & EXIT',
            onTap: () => context.goNamed(RouteNames.home),
          ),
        ],
      ),
    );
  }

  Widget _buildBiosOption({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colorScheme;
    final textColor = isSelected ? colors.surface : colors.onSurface;
    final bgColor = isSelected ? colors.onSurface : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: bgColor,
        padding: EdgeInsets.symmetric(
            horizontal: AppSizes.space, vertical: AppSizes.space * 0.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: textColor,
                fontSize: AppSizes.fontStandard,
                fontWeight: AppFonts.heavy,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: textColor,
                fontSize: AppSizes.fontStandard,
                fontWeight: AppFonts.heavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
