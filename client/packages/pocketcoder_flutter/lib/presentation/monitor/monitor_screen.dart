import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_logo.dart';
import 'package:pocketcoder_flutter/application/observability/observability_state.dart';
import 'adapters/monitor_adapter.dart';
import 'widgets/monitor_registry_and_logs.dart';

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
      footer: buildPillarFooter(context, NavPillar.status),
      showBack: false,
      body: Column(
        children: [
          AsciiLogo(text: AppAscii.bannerFor(NavPillar.status)),
          Expanded(
            child: MonitorRegistryAndLogs(
              state: state,
              onSelectContainer: onSelectContainer,
              displayName: _displayName,
              getLogColor: (log) => _getLogColor(context, log),
            ),
          ),
        ],
      ),
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
