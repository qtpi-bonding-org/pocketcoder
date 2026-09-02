import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
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
    required this.onSelectContainer,
  });

  final ObservabilityState state;
  final ValueChanged<String?> onSelectContainer;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.monitorTitle,
      activePillar: NavPillar.monitor,
      showBack: false,
      body: _buildRegistryAndLogs(context),
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
    final registry = BiosFrame(
      title: context.l10n.observabilityRegistry,
      child: ListView(
        padding: EdgeInsets.all(AppSizes.space),
        children: state.containers
            .map((c) => _buildContainerTile(context, c))
            .toList(),
      ),
    );
    final currentContainer = state.currentContainer;
    final logs = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalText.label(
          currentContainer != null
              ? _displayName(currentContainer)
              : context.l10n.observabilityLogTerminal,
        ),
        VSpace.x1,
        Expanded(child: _buildLogTerminal(context)),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Side-by-side needs enough width for the registry column and a
          // readable log panel; below that, a phone-width screen truncates
          // container names and wraps the log panel's title unreadably.
          final isNarrow = constraints.maxWidth < 600;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 220, child: registry),
                VSpace.x2,
                Expanded(child: logs),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 250, child: registry),
              HSpace.x2,
              Expanded(child: logs),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContainerTile(BuildContext context, ContainerInfo container) {
    final isSelected = state.currentContainer == container.name;
    return BiosRow(
      label: _displayName(container.name),
      value: container.state.toUpperCase(),
      isSelected: isSelected,
      labelFontSize: AppSizes.fontSmall,
      onTap: () => onSelectContainer(isSelected ? null : container.name),
    );
  }

  /// Every container in this deployment's docker-compose is named with a
  /// `pocketcoder-` prefix (see `docker-compose.yml`); it's redundant on a
  /// screen that only ever shows this deployment's own containers, so strip
  /// it for display. The underlying name (with prefix) is still what's used
  /// to select/query the container.
  String _displayName(String containerName) {
    const prefix = 'pocketcoder-';
    return containerName.toLowerCase().startsWith(prefix)
        ? containerName.substring(prefix.length)
        : containerName;
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
          '${logLine.timestamp?.toLocal().toIso8601String() ?? 'unknown'} ${logLine.message}',
          color: _getLogColor(context, logLine.message),
        );
      },
    );
  }

  Color _getLogColor(BuildContext context, String log) {
    final colors = context.colorScheme;
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
