import 'package:flutter/material.dart';
import '../../design_system/theme/app_theme.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/bios_frame.dart';
import 'package:go_router/go_router.dart';

class SystemChecksScreen extends StatelessWidget {
  const SystemChecksScreen({super.key});

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
                    title: 'SYSTEM DIAGNOSTICS',
                    child: ListView(
                      children: [
                        _buildCheckRow(
                            context, 'CORE-RELAY (GO)', 'READY', true),
                        _buildCheckRow(
                            context, 'SENTINEL-PROXY (RUST)', 'READY', true),
                        _buildCheckRow(context, 'MCP-GATEWAY', 'READY', true),
                        _buildCheckRow(
                            context, 'CAO-ORCHESTRATOR', 'READY', true),
                        _buildCheckRow(
                            context, 'OPENCODE-ENGINE', 'THINKING', true),
                        VSpace.x2,
                        _buildCheckRow(
                            context, 'DOCKER-SOCKET', 'CONNECTED', true),
                        _buildCheckRow(
                            context, 'POCKETBASE-DB', 'SYNCED', true),
                        _buildCheckRow(
                            context, 'VOLUME-MOUNTS', 'HEALTHY', true),
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
            keyLabel: 'ESC',
            label: 'BACK',
            onTap: () => context.pop(),
          ),
          TerminalAction(
            keyLabel: 'F10',
            label: 'FULL REBOOT',
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
          'SYSTEM CHECKS',
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

  Widget _buildCheckRow(
    BuildContext context,
    String component,
    String status,
    bool isOk,
  ) {
    final colors = context.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.space * 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            component,
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: colors.onSurface,
              fontWeight: AppFonts.heavy,
            ),
          ),
          Text(
            '[$status]',
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: isOk ? colors.primary : colors.error,
              fontWeight: AppFonts.heavy,
            ),
          ),
        ],
      ),
    );
  }
}
