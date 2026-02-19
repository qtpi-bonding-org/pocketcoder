import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app_router.dart';
import '../../design_system/theme/app_theme.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/bios_frame.dart';

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
                _buildHeader(context),
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
            keyLabel: 'F1',
            label: 'DASHBOARD',
            onTap: () => context.goNamed(RouteNames.home),
          ),
          TerminalAction(
            keyLabel: 'F3',
            label: 'SETTINGS',
            onTap: () => context.goNamed(RouteNames.settings),
          ),
          TerminalAction(
            keyLabel: 'ESC',
            label: 'BACK',
            onTap: () => context.pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Text(
          'SOURCE OUTPUT MANIFEST',
          style: TextStyle(
            fontFamily: AppFonts.headerFamily,
            color: context.colorScheme.onSurface,
            fontSize: AppSizes.fontBig,
            fontWeight: AppFonts.heavy,
            letterSpacing: 2,
          ),
        ),
        VSpace.x1,
        Container(
          height: AppSizes.borderWidth,
          color: context.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildArtifactList(BuildContext context) {
    // For now, showing an empty state, but formatted in terminal style
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'NO ARTIFACTS IN REGISTRY.',
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: Colors.grey,
            ),
          ),
          Text(
            '>> WORKSPACE IS CLEAN',
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: Colors.grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
