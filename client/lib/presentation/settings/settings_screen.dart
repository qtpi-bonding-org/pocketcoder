import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../design_system/primitives/app_fonts.dart';
import '../../design_system/primitives/app_palette.dart';
import '../../design_system/primitives/app_sizes.dart';
import '../../design_system/primitives/spacers.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../../app_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;

  final List<(String, String)> _options = [
    ('BOOT SEQUENCE', '[INTERNAL]'),
    ('SECURITY LEVEL', '[HIGH]'),
    ('AI MODEL', '[GPT-4o]'),
    ('THEME', '[CYBERPUNK]'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.primary.backgroundPrimary, // BIOS Black
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
                      onTap: () => setState(() => _selectedIndex = i),
                    ),
                  VSpace.x2,
                  Text(
                    'Use ARROW KEYS to navigate.\nPress ENTER to change value.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: AppPalette.primary.textPrimary,
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
    final textColor = isSelected
        ? AppPalette.primary.backgroundPrimary
        : AppPalette.primary.textPrimary;
    final bgColor =
        isSelected ? AppPalette.primary.textPrimary : Colors.transparent;

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

class BiosFrame extends StatelessWidget {
  final Widget child;
  final String? title;

  const BiosFrame({
    super.key,
    required this.child,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = AppPalette.primary.textPrimary; // BIOS Green

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: 500,
          constraints: BoxConstraints(
              maxWidth: constraints.maxWidth - AppSizes.space * 4),
          child: Stack(
            children: [
              // Main Box
              Container(
                margin: EdgeInsets.only(
                    top: AppSizes.space * 1.25), // Space for title
                padding: EdgeInsets.all(AppSizes.space * 2),
                decoration: BoxDecoration(
                  color: AppPalette.primary.backgroundPrimary,
                  border: Border.all(
                      color: borderColor, width: AppSizes.borderWidthThick),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.2),
                      blurRadius: AppSizes.radiusSmall + 2,
                      spreadRadius: AppSizes.borderWidthThick,
                    ),
                  ],
                ),
                child: child,
              ),
              // Title Overlay
              if (title != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      color: AppPalette.primary.backgroundPrimary,
                      padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
                      child: Text(
                        '[ $title ]',
                        style: TextStyle(
                          fontFamily: AppFonts.bodyFamily,
                          color: borderColor,
                          fontWeight: AppFonts.heavy,
                          backgroundColor: AppPalette.primary.backgroundPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
