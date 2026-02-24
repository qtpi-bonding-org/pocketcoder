import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app_router.dart';
import '../../design_system/theme/app_theme.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/bios_frame.dart';
import '../core/widgets/terminal_header.dart';
import '../core/widgets/bios_section.dart';

class ArtifactScreen extends StatelessWidget {
  const ArtifactScreen({super.key});

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
              children: [
                const TerminalHeader(title: 'SOURCE OUTPUT MANIFEST'),
                VSpace.x2,
                Expanded(
                  child: BiosFrame(
                    title: 'DELIVERABLES & ARTIFACTS',
                    child: _buildArtifactList(context),
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
            label: 'DASHBOARD',
            onTap: () => context.goNamed(RouteNames.home),
          ),
          TerminalAction(
            label: 'SETTINGS',
            onTap: () => context.goNamed(RouteNames.settings),
          ),
          TerminalAction(
            label: 'BACK',
            onTap: () => context.pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildArtifactList(BuildContext context) {
    final colors = context.colorScheme;
    // For now, showing an empty state, but formatted in terminal style
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BiosSection(
            title: 'REGISTRY STATUS',
            child: Column(
              children: [
                Text(
                  'NO ARTIFACTS IN REGISTRY.',
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: colors.onSurface.withValues(alpha: 0.5),
                    package: 'pocketcoder_flutter',
                  ),
                ),
                Text(
                  '>> WORKSPACE IS CLEAN',
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: colors.onSurface.withValues(alpha: 0.5),
                    fontSize: AppSizes.fontMini,
                    package: 'pocketcoder_flutter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
