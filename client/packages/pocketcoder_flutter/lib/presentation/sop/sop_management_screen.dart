import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';

class SopManagementScreen extends StatelessWidget {
  const SopManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TerminalScaffold(
      title: 'SOP MANAGEMENT',
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
      body: BiosFrame(
        title: 'PROJECT PROCEDURES',
        child: ListView(
          padding: EdgeInsets.all(AppSizes.space),
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
            VSpace.x2,
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
