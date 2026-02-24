import 'package:flutter/material.dart';
import '../../design_system/theme/app_theme.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/bios_frame.dart';
import '../core/widgets/terminal_header.dart';
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
                TerminalHeader(title: 'SYSTEM CHECKS'),
                VSpace.x2,
                Expanded(
                  child: BiosFrame(
                    title: 'SYSTEM DIAGNOSTICS',
                    child: ListView(
                      children: [
                        _buildCheckRow(context, 'POCKETBASE', 'READY', true),
                        _buildCheckRow(context, 'OPENCODE', 'READY', true),
                        _buildCheckRow(context, 'SANDBOX', 'READY', true),
                        _buildCheckRow(context, 'MCP-GATEWAY', 'READY', true),
                        _buildCheckRow(context, 'DOCKER-SOCKET-PROXY-WRITE',
                            'READY', true),
                        _buildCheckRow(context, 'SQLPAGE', 'READY', true),
                        _buildCheckRow(context, 'DOCS', 'READY', true),
                        VSpace.x2,
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
            label: 'BACK',
            onTap: () => context.pop(),
          ),
          TerminalAction(
            label: 'FULL REBOOT',
            onTap: () {},
          ),
        ],
      ),
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
