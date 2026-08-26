import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/application/observability/observability_state.dart';
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart';
import 'adapters/monitor_adapter.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context) => const MonitorAdapter();
}

class MonitorView extends StatelessWidget {
  const MonitorView({
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
      title: context.l10n.monitorTitle,
      activePillar: NavPillar.monitor,
      showBack: false,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.space,
            vertical: AppSizes.space * 0.5,
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: TerminalButton(
              label: context.l10n.actionRefresh,
              isLoading: state.isLoading,
              onTap: onRefresh,
            ),
          ),
        ),
        _buildHealthStatus(context),
        VSpace.x2,
        Expanded(child: _buildRegistryAndLogs(context)),
      ],
    );
  }

  Widget _buildHealthStatus(BuildContext context) {
    final stats = state.stats;
    if (stats == null) return const SizedBox.shrink();
    final isHealthy = stats.backendStatus.toLowerCase() == 'healthy' ||
        stats.backendStatus.toLowerCase() == 'ready';
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
      child: BiosFrame(
        title: 'BACKEND',
        child: BiosRow(
          label: 'BACKEND STATUS',
          value: '[ ${stats.backendStatus.toUpperCase()} ]',
          isDestructive: !isHealthy,
        ),
      ),
    );
  }

  Widget _buildRegistryAndLogs(BuildContext context) {
    if (state.hasError && state.containers.isEmpty) {
      return Center(
        child: TerminalText.label(
          context.l10n.monitorTelemetryUnavailable,
          color: context.terminalColors.warning,
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 250,
            child: BiosFrame(
              title: context.l10n.observabilityRegistry,
              child: ListView(
                padding: EdgeInsets.all(AppSizes.space),
                children: state.containers
                    .map((c) => _buildContainerTile(context, c))
                    .toList(),
              ),
            ),
          ),
          HSpace.x2,
          Expanded(
            child: BiosFrame(
              title: state.currentContainer != null
                  ? 'LOGS: ${state.currentContainer}'
                  : context.l10n.observabilityLogTerminal,
              child: _buildLogTerminal(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContainerTile(BuildContext context, ContainerInfo container) {
    final isSelected = state.currentContainer == container.name;
    return BiosRow(
      label: container.name,
      value: container.state.toUpperCase(),
      isSelected: isSelected,
      onTap: () => onSelectContainer(isSelected ? null : container.name),
    );
  }

  Widget _buildLogTerminal(BuildContext context) {
    if (state.currentContainer == null) {
      return Center(
        child: TerminalText(
          context.l10n.observabilitySelectContainer,
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
          color: _getLogColor(context, logLine),
        );
      },
    );
  }

  Color _getLogColor(BuildContext context, String log) {
    final colors = context.colorScheme;
    final terminal = context.terminalColors;
    final upper = log.toUpperCase();
    if (upper.contains('ERR') || upper.contains('FAIL')) return terminal.warning;
    if (upper.contains('WARN')) return terminal.warning;
    if (upper.contains('INFO')) return colors.primary;
    if (upper.contains('DEBUG')) return colors.secondary;
    return colors.onSurface.withValues(alpha: 0.7);
  }
}
