import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_metric_box.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/application/observability/observability_state.dart';
import 'adapters/agent_observability_adapter.dart';

class AgentObservabilityScreen extends StatelessWidget {
  const AgentObservabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AgentObservabilityAdapter();
  }
}

class AgentObservabilityView extends StatelessWidget {
  const AgentObservabilityView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onSelectContainer,
  });

  final ObservabilityState state;
  final VoidCallback onRefresh;
  final ValueChanged<String?> onSelectContainer;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
            title: context.l10n.observabilityTitle,
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
                      label: context.l10n.actionRefresh,
                      onTap: onRefresh,
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
                          title: context.l10n.observabilityRegistry,
                          child: ListView(
                            padding: EdgeInsets.all(AppSizes.space),
                            children: [
                              _buildContainerTile(
                                context,
                                'pocketbase',
                                'pocketcoder-pocketbase',
                                state.currentContainer,
                                onSelectContainer,
                              ),
                              _buildContainerTile(
                                context,
                                'mcp-gateway',
                                'pocketcoder-mcp-gateway',
                                state.currentContainer,
                                onSelectContainer,
                              ),
                              _buildContainerTile(
                                context,
                                'pocket-memory',
                                'pocketcoder-memory',
                                state.currentContainer,
                                onSelectContainer,
                              ),
                              _buildContainerTile(
                                context,
                                'sqlpage',
                                'pocketcoder-sqlpage',
                                state.currentContainer,
                                onSelectContainer,
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
                              : context.l10n.observabilityLogTerminal,
                          child: _buildLogTerminal(context, state),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
        TerminalMetricBox(label: context.l10n.observabilityCost, value: stats.cumulativeCost),
        HSpace.x2,
        TerminalMetricBox(
            label: context.l10n.observabilityTokens, value: stats.cumulativeTokens.toString()),
        HSpace.x2,
        TerminalMetricBox(
            label: context.l10n.observabilityMsgs, value: stats.totalMessages.toString()),
        HSpace.x2,
        TerminalMetricBox(
            label: context.l10n.observabilityBackend, value: stats.backendStatus.toUpperCase()),
      ],
    );
  }

  Widget _buildContainerTile(
    BuildContext context,
    String label,
    String containerId,
    String? current,
    ValueChanged<String?> onSelect,
  ) {
    final isSelected = current == containerId;
    return BiosRow(
      label: label,
      value: containerId,
      isSelected: isSelected,
      onTap: () => onSelect(isSelected ? null : containerId),
    );
  }

  Widget _buildLogTerminal(BuildContext context, ObservabilityState state) {
    final colors = context.colorScheme;

    if (state.currentContainer == null) {
      return Center(
        child: TerminalText(
          '${context.l10n.observabilitySelectContainer}\n>> AUTHENTICATED AS POCKETCODER ADMIN',
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
      return terminal.warning;
    }
    if (upper.contains('WARN')) return terminal.warning;
    if (upper.contains('INFO')) return colors.primary;
    if (upper.contains('DEBUG')) return colors.secondary;
    return colors.onSurface.withValues(alpha: 0.7);
  }
}
