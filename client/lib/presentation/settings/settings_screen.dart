import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app_router.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';

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
      backgroundColor: Colors.black, // BIOS Black
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
                  const SizedBox(height: 16),
                  const Text(
                    'Use ARROW KEYS to navigate.\nPress ENTER to change value.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Noto Sans Mono',
                      color: Color(0xFF00FF00),
                      fontSize: 12,
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
    final textColor =
        isSelected ? Colors.black : const Color(0xFF00FF00); // Green text
    final bgColor = isSelected ? const Color(0xFF00FF00) : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Noto Sans Mono',
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Noto Sans Mono',
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
    const borderColor = Color(0xFF00FF00); // BIOS Green

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: 500,
          constraints: BoxConstraints(maxWidth: constraints.maxWidth - 32),
          child: Stack(
            children: [
              // Main Box
              Container(
                margin: const EdgeInsets.only(top: 10), // Space for title
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: borderColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
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
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '[ $title ]',
                        style: const TextStyle(
                          fontFamily: 'Noto Sans Mono',
                          color: borderColor,
                          fontWeight: FontWeight.bold,
                          backgroundColor: Colors.black,
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
