import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/observability/observability_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/monitor/widgets/log_terminal.dart';

class MonitorRegistryAndLogs extends StatelessWidget {
  const MonitorRegistryAndLogs({
    super.key,
    required this.state,
    required this.onSelectContainer,
    required this.displayName,
    required this.getLogColor,
  });

  final ObservabilityState state;
  final ValueChanged<String?> onSelectContainer;
  final String Function(String) displayName;
  final Color Function(String) getLogColor;

  @override
  Widget build(BuildContext context) {
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
            .map(
              (container) => MonitorContainerTile(
                container: container,
                isSelected: state.currentContainer == container.name,
                displayName: displayName,
                onSelectContainer: onSelectContainer,
              ),
            )
            .toList(),
      ),
    );
    final currentContainer = state.currentContainer;
    final logs = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalText.label(
          currentContainer != null
              ? displayName(currentContainer)
              : context.l10n.observabilityLogTerminal,
        ),
        VSpace.x1,
        Expanded(
          child: MonitorLogTerminal(
            state: state,
            getLogColor: getLogColor,
          ),
        ),
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
}

class MonitorContainerTile extends StatelessWidget {
  const MonitorContainerTile({
    super.key,
    required this.container,
    required this.isSelected,
    required this.displayName,
    required this.onSelectContainer,
  });

  final ContainerInfo container;
  final bool isSelected;
  final String Function(String) displayName;
  final ValueChanged<String?> onSelectContainer;

  @override
  Widget build(BuildContext context) {
    return BiosRow(
      label: displayName(container.name),
      value: container.state.toUpperCase(),
      isSelected: isSelected,
      labelFontSize: AppSizes.fontBody,
      onTap: () => onSelectContainer(isSelected ? null : container.name),
    );
  }
}
