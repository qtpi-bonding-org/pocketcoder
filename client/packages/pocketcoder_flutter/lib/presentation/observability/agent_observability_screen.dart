import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import '../../app_router.dart';
import 'package:flutter_aeroform/application/observability/observability_cubit.dart';
import 'package:flutter_aeroform/application/observability/observability_state.dart';
import 'package:go_router/go_router.dart';

class AgentObservabilityScreen extends StatelessWidget {
  const AgentObservabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return UiFlowListener<ObservabilityCubit, ObservabilityState>(
      child: BlocBuilder<ObservabilityCubit, ObservabilityState>(
        builder: (context, state) {
          return TerminalScaffold(
            title: 'PLATFORM OBSERVABILITY',
            actions: [
              TerminalAction(
                label: 'DASHBOARD',
                onTap: () => context.goNamed(RouteNames.home),
              ),
              TerminalAction(
                label: 'REFRESH',
                onTap: () => context.read<ObservabilityCubit>().refreshStats(),
              ),
              TerminalAction(
                label: 'BACK',
                onTap: () => context.pop(),
              ),
            ],
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMetricsRow(context, state),
                VSpace.x2,
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 📂 Container Registry
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
                      // 📜 Live Logs
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
    if (state.stats == null) {
      return const SizedBox.shrink();
    }
    final stats = state.stats!;
    return Row(
      children: [
        _buildMetricBox(context, 'COST', stats.cumulativeCost),
        HSpace.x2,
        _buildMetricBox(context, 'TOKENS', stats.cumulativeTokens.toString()),
        HSpace.x2,
        _buildMetricBox(context, 'MSGS', stats.totalMessages.toString()),
        HSpace.x2,
        _buildMetricBox(context, 'BACKEND', stats.backendStatus.toUpperCase()),
      ],
    );
  }

  Widget _buildMetricBox(BuildContext context, String label, String value) {
    final colors = context.colorScheme;
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(AppSizes.space),
        decoration: BoxDecoration(
          border: Border.all(color: colors.primary.withValues(alpha: 0.5)),
          color: colors.primary.withValues(alpha: 0.05),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: colors.primary,
                fontSize: AppSizes.fontMini,
                fontWeight: AppFonts.heavy,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: colors.onSurface,
                fontSize: AppSizes.fontStandard,
                fontWeight: AppFonts.heavy,
              ),
            ),
          ],
        ),
      ),
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
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: isSelected ? colors.primary : colors.onSurface,
                fontWeight: AppFonts.heavy,
              ),
            ),
            Text(
              containerId,
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: colors.onSurface.withValues(alpha: 0.5),
                fontSize: AppSizes.fontMini,
              ),
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
        child: Text(
          '>> SELECT CONTAINER FOR LOG STREAM\n>> AUTHENTICATED AS POCKETCODER ADMIN',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface.withValues(alpha: 0.3),
            fontSize: AppSizes.fontSmall,
          ),
        ),
      );
    }

    return ListView.builder(
      reverse: true, // Show latest logs at bottom
      padding: EdgeInsets.all(AppSizes.space),
      itemCount: state.logs.length,
      itemBuilder: (context, index) {
        final logLine = state.logs[state.logs.length - 1 - index];
        return Text(
          logLine,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: _getLogColor(logLine, colors),
            fontSize: AppSizes.fontMini,
          ),
        );
      },
    );
  }

  Color _getLogColor(String log, ColorScheme colors) {
    final upper = log.toUpperCase();
    if (upper.contains('ERR') || upper.contains('FAIL')) {
      return Colors.redAccent;
    }
    if (upper.contains('WARN')) return Colors.orangeAccent;
    if (upper.contains('INFO')) return colors.primary;
    if (upper.contains('DEBUG')) return colors.secondary;
    return colors.onSurface.withValues(alpha: 0.7);
  }
}
