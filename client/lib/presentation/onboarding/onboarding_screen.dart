import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app_router.dart';
import '../core/widgets/ascii_art.dart';
import '../core/widgets/ascii_logo.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/poco_animator.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: ScanlineWidget(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AsciiLogo(
                  text: AppAscii.pocketCoderLogo,
                  fontSize: 16,
                ),
                const SizedBox(height: 32),
                const PocoAnimator(fontSize: 24),
                const SizedBox(height: 16),
                const Text(
                  'WELCOME TO POCKETCODER',
                  style: TextStyle(
                    fontFamily: 'Share Tech Mono',
                    color: Color(0xFF39FF14),
                    fontSize: 24,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'INITIALIZE SYSTEM TO BEGIN',
                  style: TextStyle(
                    fontFamily: 'Noto Sans Mono',
                    color: const Color(0xFF39FF14).withValues(alpha: 0.7),
                    fontSize: 14,
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
            label: 'START SYSTEM',
            onTap: () => context.goNamed(RouteNames.home),
          ),
          TerminalAction(
            keyLabel: 'F10',
            label: 'SHUTDOWN',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
