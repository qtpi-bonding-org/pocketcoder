import 'package:flutter/material.dart';
import '../../design_system/theme/app_theme.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/bios_frame.dart';
import 'package:go_router/go_router.dart';

class SopManagementScreen extends StatelessWidget {
  const SopManagementScreen({super.key});

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
                _buildHeader(context),
                VSpace.x2,
                Expanded(
                  child: BiosFrame(
                    title: 'PROJECT PROCEDURES (SOP)',
                    child: ListView(
                      children: [
                        _buildSectionHeader(context, 'ACTIVE PROCEDURES'),
                        _buildSopItem(
                          context,
                          title: 'DEPLOYMENT-PIPELINE',
                          version: '1.2',
                          lastUpdated: '2026-02-18',
                        ),
                        _buildSopItem(
                          context,
                          title: 'CODE-REVIEW-STANDARD',
                          version: '2.0',
                          lastUpdated: '2026-02-15',
                        ),
                        VSpace.x2,
                        _buildSectionHeader(context, 'DRAFT PROPOSALS'),
                        _buildSopItem(
                          context,
                          title: 'DOCKER-SECURITY-HARDENING',
                          version: 'DRAFT',
                          lastUpdated: 'PENDING SIGNATURE',
                          isDraft: true,
                        ),
                      ],
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
            label: 'BACK',
            onTap: () => context.pop(),
          ),
          TerminalAction(
            label: 'NEW PROPOSAL',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SOP MANAGEMENT',
          style: TextStyle(
            fontFamily: AppFonts.headerFamily,
            color: colors.onSurface,
            fontSize: AppSizes.fontBig,
            fontWeight: AppFonts.heavy,
            letterSpacing: 2,
          ),
        ),
        VSpace.x1,
        Container(
          height: AppSizes.borderWidth,
          color: colors.onSurface.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = context.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.space),
      child: Text(
        '--- $title ---',
        style: TextStyle(
          fontFamily: AppFonts.bodyFamily,
          color: colors.onSurface.withValues(alpha: 0.5),
          fontSize: AppSizes.fontTiny,
          fontWeight: AppFonts.heavy,
        ),
      ),
    );
  }

  Widget _buildSopItem(
    BuildContext context, {
    required String title,
    required String version,
    required String lastUpdated,
    bool isDraft = false,
  }) {
    final colors = context.colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.3)),
        color: isDraft ? colors.primary.withValues(alpha: 0.05) : null,
      ),
      child: InkWell(
        onTap: () {},
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: colors.onSurface,
                      fontWeight: AppFonts.heavy,
                    ),
                  ),
                  Text(
                    'VER: $version | UPDATED: $lastUpdated',
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: colors.onSurface.withValues(alpha: 0.5),
                      fontSize: AppSizes.fontMini,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colors.onSurface.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
