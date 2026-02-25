import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/scanline_widget.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
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
                const TerminalHeader(title: 'SOP MANAGEMENT'),
                VSpace.x2,
                Expanded(
                  child: BiosFrame(
                    title: 'PROJECT PROCEDURES',
                    child: ListView(
                      children: [
                        BiosSection(
                          title: 'ACTIVE PROCEDURES',
                          child: Column(
                            children: [
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
                            ],
                          ),
                        ),
                        BiosSection(
                          title: 'DRAFT PROPOSALS',
                          child: _buildSopItem(
                            context,
                            title: 'DOCKER-SECURITY-HARDENING',
                            version: 'DRAFT',
                            lastUpdated: 'PENDING SIGNATURE',
                            isDraft: true,
                          ),
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
