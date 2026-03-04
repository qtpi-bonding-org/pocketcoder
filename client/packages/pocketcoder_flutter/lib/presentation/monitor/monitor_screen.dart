import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/application/observability/observability_cubit.dart';
import 'package:pocketcoder_flutter/application/observability/observability_state.dart';
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ObservabilityCubit>().refreshStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ObservabilityCubit, ObservabilityState>(
      builder: (context, state) {
        return PocketCoderShell(
          title: 'MONITOR',
          activePillar: NavPillar.monitor,
          showBack: false,
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ObservabilityState state) {
    final colors = context.colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.space),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inline REFRESH button
          Align(
            alignment: Alignment.centerRight,
            child: TerminalButton(
              label: 'REFRESH',
              isLoading: state.isLoading,
              onTap: () => context.read<ObservabilityCubit>().refreshStats(),
            ),
          ),
          VSpace.x2,

          if (state.isLoading && state.stats == null)
            const Center(
              child: TerminalLoadingIndicator(label: 'FETCHING TELEMETRY'),
            )
          else if (state.stats != null) ...[
            // System Health
            BiosSection(
              title: 'SYSTEM HEALTH',
              child: _buildHealthStatus(context, state.stats!),
            ),

            // Key Metrics
            BiosSection(
              title: 'KEY METRICS',
              child: _buildMetricsGrid(context, state.stats!),
            ),

            // Token Usage by Model
            if (state.stats!.tokenUsage.isNotEmpty)
              BiosSection(
                title: 'TOKEN USAGE BY MODEL',
                child: _buildTokenUsage(context, state.stats!.tokenUsage),
              ),

            // Agent Activity (CAO Tasks)
            if (state.stats!.tasks.isNotEmpty)
              BiosSection(
                title: 'AGENT ACTIVITY',
                child: _buildAgentActivity(context, state.stats!.tasks),
              ),
          ] else if (state.hasError)
            Center(
              child: Text(
                'TELEMETRY UNAVAILABLE',
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.error,
                  fontWeight: AppFonts.heavy,
                ),
              ),
            )
          else
            Center(
              child: Text(
                'NO DATA — TAP REFRESH',
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHealthStatus(BuildContext context, SystemStats stats) {
    final colors = context.colorScheme;
    final isHealthy = stats.backendStatus.toLowerCase() == 'healthy' ||
        stats.backendStatus.toLowerCase() == 'ready';

    return BiosFrame(
      title: 'BACKEND',
      child: Padding(
        padding: EdgeInsets.all(AppSizes.space),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'BACKEND STATUS',
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: colors.onSurface,
                fontWeight: AppFonts.heavy,
              ),
            ),
            Text(
              '[ ${stats.backendStatus.toUpperCase()} ]',
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: isHealthy ? colors.primary : colors.error,
                fontWeight: AppFonts.heavy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, SystemStats stats) {
    final colors = context.colorScheme;
    return Row(
      children: [
        _buildMetricCard(
            context, 'MESSAGES', stats.totalMessages.toString(), colors.primary),
        HSpace.x1,
        _buildMetricCard(
            context, 'COST', stats.cumulativeCost, colors.primary),
        HSpace.x1,
        _buildMetricCard(context, 'TOKENS',
            _formatNumber(stats.cumulativeTokens), colors.primary),
      ],
    );
  }

  Widget _buildMetricCard(
      BuildContext context, String label, String value, Color accent) {
    final colors = context.colorScheme;
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(AppSizes.space * 1.5),
        decoration: BoxDecoration(
          border: Border.all(color: accent.withValues(alpha: 0.5)),
          color: accent.withValues(alpha: 0.05),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: accent,
                fontSize: AppSizes.fontMini,
                fontWeight: AppFonts.heavy,
                letterSpacing: 1,
              ),
            ),
            VSpace.x1,
            Text(
              value,
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: colors.onSurface,
                fontSize: AppSizes.fontBig,
                fontWeight: AppFonts.heavy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenUsage(BuildContext context, List<TokenUsage> usage) {
    final colors = context.colorScheme;
    return Column(
      children: usage.map((entry) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: AppSizes.space * 0.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  entry.model.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: colors.onSurface,
                    fontWeight: AppFonts.heavy,
                    fontSize: AppSizes.fontSmall,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatNumber(entry.tokens),
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.primary,
                  fontWeight: AppFonts.heavy,
                  fontSize: AppSizes.fontSmall,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAgentActivity(
      BuildContext context, List<OperationalTask> tasks) {
    final colors = context.colorScheme;
    return Column(
      children: tasks.map((task) {
        final isActive = task.status.toLowerCase() == 'active' ||
            task.status.toLowerCase() == 'running';
        return Container(
          margin: EdgeInsets.only(bottom: AppSizes.space),
          padding: EdgeInsets.all(AppSizes.space),
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive
                  ? colors.primary.withValues(alpha: 0.5)
                  : colors.onSurface.withValues(alpha: 0.2),
            ),
            color: isActive ? colors.primary.withValues(alpha: 0.05) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${task.sender} -> ${task.receiver}'.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: colors.onSurface,
                      fontWeight: AppFonts.heavy,
                      fontSize: AppSizes.fontSmall,
                    ),
                  ),
                  Text(
                    '[ ${task.status.toUpperCase()} ]',
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: isActive ? colors.primary : colors.onSurface.withValues(alpha: 0.5),
                      fontWeight: AppFonts.heavy,
                      fontSize: AppSizes.fontMini,
                    ),
                  ),
                ],
              ),
              if (task.summary.isNotEmpty) ...[
                VSpace.x1,
                Text(
                  task.summary,
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: colors.onSurface.withValues(alpha: 0.7),
                    fontSize: AppSizes.fontMini,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              VSpace.x1,
              Text(
                task.timestamp,
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface.withValues(alpha: 0.3),
                  fontSize: AppSizes.fontMini,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
