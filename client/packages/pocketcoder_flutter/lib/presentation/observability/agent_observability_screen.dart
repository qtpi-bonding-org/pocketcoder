import 'package:flutter/material.dart';
import '../../design_system/theme/app_theme.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/bios_frame.dart';
import '../core/widgets/terminal_header.dart';
import '../core/widgets/bios_section.dart';
import 'package:go_router/go_router.dart';

class AgentObservabilityScreen extends StatelessWidget {
  const AgentObservabilityScreen({super.key});

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
                const TerminalHeader(title: 'AGENT OBSERVABILITY'),
                VSpace.x2,
                Expanded(
                  child: BiosFrame(
                    title: 'ACTIVE SESSIONS',
                    child: BiosSection(
                      title: 'CONNECTED AGENTS',
                      child: Column(
                        children: [
                          _buildAgentRow(
                            context,
                            name: 'POCO-ORCHESTRATOR',
                            status: 'IDLE',
                            window: '0',
                            isMain: true,
                          ),
                          _buildAgentRow(
                            context,
                            name: 'DEVELOPER-7FB2',
                            status: 'RUNNING',
                            window: '1',
                          ),
                          _buildAgentRow(
                            context,
                            name: 'RESEARCHER-A411',
                            status: 'THINKING',
                            window: '2',
                          ),
                        ],
                      ),
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
            label: 'REFRESH',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildAgentRow(
    BuildContext context, {
    required String name,
    required String status,
    required String window,
    bool isMain = false,
  }) {
    final colors = context.colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.3)),
        color: isMain ? colors.onSurface.withValues(alpha: 0.05) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  'STATUS: $status | TTY: PANE $window',
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: colors.onSurface.withValues(alpha: 0.5),
                    fontSize: AppSizes.fontMini,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: Text(
              'ATTACH',
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: colors.primary,
                fontWeight: AppFonts.heavy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
