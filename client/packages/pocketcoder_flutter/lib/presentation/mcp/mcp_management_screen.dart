import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/scanline_widget.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';

class McpManagementScreen extends StatelessWidget {
  const McpManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<McpCubit>()..watchServers(),
      child: UiFlowListener<McpCubit, McpState>(
        child: const _McpManagementView(),
      ),
    );
  }
}

class _McpManagementView extends StatelessWidget {
  const _McpManagementView();

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
                const TerminalHeader(title: 'MCP MANAGEMENT'),
                VSpace.x2,
                Expanded(
                  child: BiosFrame(
                    title: 'CAPABILITIES REGISTRY',
                    child: BlocBuilder<McpCubit, McpState>(
                      builder: (context, state) {
                        return state.maybeWhen(
                          loaded: (servers) {
                            final pending = servers
                                .where(
                                    (s) => s.status == McpServerStatus.pending)
                                .toList();
                            final active = servers
                                .where(
                                    (s) => s.status != McpServerStatus.pending)
                                .toList();

                            return ListView(
                              children: [
                                if (pending.isNotEmpty)
                                  BiosSection(
                                    title: 'PENDING APPROVAL',
                                    child: Column(
                                      children: pending
                                          .map((s) => _buildMcpItem(context, s))
                                          .toList(),
                                    ),
                                  ),
                                if (active.isNotEmpty)
                                  BiosSection(
                                    title: 'ACTIVE CAPABILITIES',
                                    child: Column(
                                      children: active
                                          .map((s) => _buildMcpItem(context, s))
                                          .toList(),
                                    ),
                                  ),
                                if (servers.isEmpty)
                                  Center(
                                    child: Padding(
                                      padding:
                                          EdgeInsets.all(AppSizes.space * 4),
                                      child: Text(
                                        'NO CAPABILITIES REGISTERED',
                                        style: TextStyle(
                                          color: colors.onSurface
                                              .withValues(alpha: 0.5),
                                          fontFamily: AppFonts.bodyFamily,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (msg) => Center(
                            child: Text(
                              'ERROR: $msg',
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        );
                      },
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
            onTap: () {}, // TODO: Implement add new MCP
          ),
        ],
      ),
    );
  }

  Widget _buildMcpItem(BuildContext context, McpServer server) {
    final colors = context.colorScheme;
    final isPending = server.status == McpServerStatus.pending;

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
                server.name.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface,
                  fontWeight: AppFonts.heavy,
                ),
              ),
              Text(
                server.status.name.toUpperCase(),
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
          if (server.reason != null && server.reason!.isNotEmpty) ...[
            VSpace.x1,
            Text(
              'PURPOSE: ${server.reason}',
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: colors.onSurface.withValues(alpha: 0.5),
                fontSize: AppSizes.fontMini,
              ),
            ),
          ],
          if (isPending) ...[
            VSpace.x1,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        context.read<McpCubit>().authorize(server.id),
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
                  onPressed: () => context.read<McpCubit>().deny(server.id),
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
