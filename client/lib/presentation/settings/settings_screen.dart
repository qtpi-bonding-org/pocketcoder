import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app_router.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000088), // BIOS Blue background
      body: ScanlineWidget(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    color: const Color(0xFFAAAAAA), // BIOS Grey
                    child: const Text(
                      'POCKETCODER BIOS SETUP UTILITY',
                      style: TextStyle(
                        fontFamily: 'VT323',
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildBiosOption('System Time', '23:45:01'),
                _buildBiosOption('Secure Boot', 'ENABLED'),
                _buildBiosOption('Gatekeeper', 'ACTIVE'),
                _buildBiosOption('AI Core', 'ONLINE'),
              ],
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

  Widget _buildBiosOption(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'VT323',
              color: Color(0xFFAAAAAA),
              fontSize: 18,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'VT323',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
