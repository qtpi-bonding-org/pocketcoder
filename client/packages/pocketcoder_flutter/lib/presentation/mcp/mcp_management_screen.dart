import 'package:flutter/material.dart';
import '../../design_system/theme/app_theme.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/bios_frame.dart';
import 'package:go_router/go_router.dart';

class McpManagementScreen extends StatelessWidget {
  const McpManagementScreen({super.key});

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
                    title: 'MCP CAPABILITIES',
                    child: ListView(
                      children: [
                        _buildSectionHeader(context, 'PENDING APPROVAL'),
                        _buildMcpItem(
                          context,
                          name: 'GOOGLE-SEARCH-MCP',
                          source: 'SUBAGENT ANALYSIS-1',
                          status: 'PENDING',
                          isPending: true,
                        ),
                        VSpace.x2,
                        _buildSectionHeader(context, 'ACTIVE CAPABILITIES'),
                        _buildMcpItem(
                          context,
                          name: 'FILE-SYSTEM-MCP',
                          source: 'SYSTEM-DEFAULT',
                          status: 'AUTHORIZED',
                        ),
                        _buildMcpItem(
                          context,
                          name: 'BASH-EXEC-MCP',
                          source: 'SYSTEM-DEFAULT',
                          status: 'AUTHORIZED',
                        ),
                        _buildMcpItem(
                          context,
                          name: 'GIT-TOOL-MCP',
                          source: 'USER-APPROVED',
                          status: 'AUTHORIZED',
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
            label: 'ADD NEW',
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
          'MCP MANAGEMENT',
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

  Widget _buildMcpItem(
    BuildContext context, {
    required String name,
    required String source,
    required String status,
    bool isPending = false,
  }) {
    final colors = context.colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        border: Border.all(
          color: isPending
              ? colors.primary
              : colors.onSurface.withValues(alpha: 0.3),
        ),
        color: isPending ? colors.primary.withValues(alpha: 0.05) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface,
                  fontWeight: AppFonts.heavy,
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: isPending
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.7),
                  fontSize: AppSizes.fontTiny,
                  fontWeight: AppFonts.heavy,
                ),
              ),
            ],
          ),
          VSpace.x1,
          Text(
            'REQUESTED BY: $source',
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: colors.onSurface.withValues(alpha: 0.5),
              fontSize: AppSizes.fontMini,
            ),
          ),
          if (isPending) ...[
            VSpace.x1,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(color: colors.primary),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                    child: const Text('AUTHORIZE CAPABILITY'),
                  ),
                ),
                HSpace.x2,
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(color: colors.error),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  child: const Text('DENY'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
