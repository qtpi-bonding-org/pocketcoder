import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app_router.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';

class ArtifactScreen extends StatelessWidget {
  const ArtifactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: ScanlineWidget(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ARTIFACTS & DELIVERABLES',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF39FF14),
                        fontFamily: 'Share Tech Mono',
                        letterSpacing: 2,
                      ),
                ),
                Container(
                  height: 1,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: const Color(0xFF39FF14).withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                const Text(
                  'NO ARTIFACTS FOUND.',
                  style: TextStyle(
                    fontFamily: 'Noto Sans Mono',
                    color: Color(0xFF39FF14),
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
            keyLabel: 'F1',
            label: 'DASHBOARD',
            onTap: () => context.goNamed(RouteNames.home),
          ),
          TerminalAction(
            keyLabel: 'F3',
            label: 'SETTINGS',
            onTap: () => context.goNamed(RouteNames.settings),
          ),
        ],
      ),
    );
  }
}
