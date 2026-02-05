import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app_router.dart';
import '../../design_system/primitives/app_fonts.dart';
import '../../design_system/primitives/app_palette.dart';
import '../../design_system/primitives/app_sizes.dart';
import '../../design_system/primitives/spacers.dart';
import '../core/widgets/ascii_art.dart';
import '../core/widgets/ascii_logo.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/poco_animator.dart';
import '../core/widgets/typewriter_text.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.primary.backgroundPrimary,
      body: ScanlineWidget(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AsciiLogo(
                  text: AppAscii.pocketCoderLogo,
                  fontSize: AppSizes.fontTiny, // explicit or default
                ),
                VSpace.x8,
                PocoAnimator(fontSize: AppSizes.fontLarge),
                VSpace.x2,
                TypewriterText(
                  text: 'HI! I AM POCO THE POCKETCODER.',
                  speed: const Duration(milliseconds: 60),
                  style: TextStyle(
                    fontFamily: AppFonts.headerFamily,
                    color: AppPalette.primary.textPrimary,
                    fontSize: AppSizes.fontLarge,
                    letterSpacing: 2,
                    fontWeight: AppFonts.heavy,
                  ),
                ),
                VSpace.x1,
                Text(
                  'INITIALIZE SYSTEM TO BEGIN',
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color:
                        AppPalette.primary.textPrimary.withValues(alpha: 0.7),
                    fontSize: AppSizes.fontSmall,
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
