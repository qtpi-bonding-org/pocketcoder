import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_metric_box.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/application/observability/observability_cubit.dart';
import 'package:pocketcoder_flutter/application/observability/observability_state.dart';

class AgentObservabilityScreen extends StatelessWidget {
  const AgentObservabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return UiFlowListener<ObservabilityCubit, ObservabilityState>(
      child: BlocBuilder<ObservabilityCubit, ObservabilityState>(
        builder: (context, state) {
          return PocketCoderShell(
            title: 'PLATFORM OBSERVABILITY',
            activePillar: NavPillar.configure,
            showBack: true,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Inline REFRESH button
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.space,
                    vertical: AppSizes.space * 0.5,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TerminalButton(
                      label: 'REFRESH',
                      onTap: () =>
                          context.read<ObservabilityCubit>().refreshStats(),
                    ),
                  ),
                ),
                _buildMetricsRow(context, state),
                VSpace.x2,
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Container Registry
                      SizedBox(
                        width: 250,
                        child: BiosFrame(
                          title: 'REGISTRY',
                          child: ListView(
                            padding: EdgeInsets.all(AppSizes.space),
                            children: [
                              _buildContainerTile(
                                context,
                                'pocketbase',
                                'pocketcoder-pocketbase',
                                state.currentContainer,
                              ),
                              _buildContainerTile(
                                context,
                                'opencode',
                                'pocketcoder-opencode',
                                state.currentContainer,
                              ),
                              _buildContainerTile(
                                context,
                                'sandbox (cao)',
                                'pocketcoder-sandbox',
                                state.currentContainer,
                              ),
                              _buildContainerTile(
                                context,
                                'mcp-gateway',
                                'pocketcoder-mcp-gateway',
                                state.currentContainer,
                              ),
                              _buildContainerTile(
                                context,
                                'sqlpage',
                                'pocketcoder-sqlpage',
                                state.currentContainer,
                              ),
                            ],
                          ),
                        ),
                      ),
                      HSpace.x2,
                      // Live Logs
                      Expanded(
                        child: BiosFrame(
                          title: state.currentContainer != null
                              ? 'LOGS: ${state.currentContainer}'
                              : 'SYSTEM LOG TERMINAL',
                          child: _buildLogTerminal(context, state),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricsRow(BuildContext context, ObservabilityState state) {
    final stats = state.stats;
    if (stats == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        TerminalMetricBox(label: 'COST', value: stats.cumulativeCost),
        HSpace.x2,
        TerminalMetricBox(
            label: 'TOKENS', value: stats.cumulativeTokens.toString()),
        HSpace.x2,
        TerminalMetricBox(
            label: 'MSGS', value: stats.totalMessages.toString()),
        HSpace.x2,
        TerminalMetricBox(
            label: 'BACKEND', value: stats.backendStatus.toUpperCase()),
      ],
    );
  }

  Widget _buildContainerTile(
    BuildContext context,
    String label,
    String containerId,
    String? current,
  ) {
    final colors = context.colorScheme;
    final isSelected = current == containerId;

    return InkWell(
      onTap: () {
        if (isSelected) {
          context.read<ObservabilityCubit>().stopLogStreaming();
        } else {
          context.read<ObservabilityCubit>().startLogStreaming(containerId);
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: AppSizes.space),
        padding: EdgeInsets.all(AppSizes.space),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.2),
          ),
          color: isSelected ? colors.primary.withValues(alpha: 0.1) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TerminalText.label(
              label.toUpperCase(),
              color: isSelected ? colors.primary : null,
            ),
            TerminalText.mini(
              containerId,
              alpha: 0.5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogTerminal(BuildContext context, ObservabilityState state) {
    final colors = context.colorScheme;

    if (state.currentContainer == null) {
      return Center(
        child: TerminalText(
          '>> SELECT CONTAINER FOR LOG STREAM\n>> AUTHENTICATED AS POCKETCODER ADMIN',
          textAlign: TextAlign.center,
          alpha: 0.3,
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: EdgeInsets.all(AppSizes.space),
      itemCount: state.logs.length,
      itemBuilder: (context, index) {
        final logLine = state.logs[state.logs.length - 1 - index];
        return TerminalText.mini(
          logLine,
          color: _getLogColor(context, logLine, colors),
        );
      },
    );
  }

  Color _getLogColor(
      BuildContext context, String log, ColorScheme colors) {
    final terminal = context.terminalColors;
    final upper = log.toUpperCase();
    if (upper.contains('ERR') || upper.contains('FAIL')) {
      return terminal.danger;
    }
    if (upper.contains('WARN')) return terminal.warning;
    if (upper.contains('INFO')) return colors.primary;
    if (upper.contains('DEBUG')) return colors.secondary;
    return colors.onSurface.withValues(alpha: 0.7);
  }
}
