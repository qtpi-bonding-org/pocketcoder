import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/application/observability/observability_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class MonitorLogTerminal extends StatelessWidget {
  const MonitorLogTerminal({
    super.key,
    required this.state,
    required this.getLogColor});

  final ObservabilityState state;
  final Color Function(String) getLogColor;

  @override
  Widget build(BuildContext context) {
    if (state.currentContainer == null) {
      return Center(
        child: TerminalText(
          context.l10n.observabilitySelectContainer,
          role: TextRole.body,
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: EdgeInsets.all(AppSizes.space),
      itemCount: state.logs.length,
      itemBuilder: (context, index) {
        final logLine = state.logs[state.logs.length - 1 - index];
        return TerminalText(
          '${logLine.timestamp?.toLocal().toIso8601String() ?? 'unknown'} ${logLine.message}',
          role: TextRole.body,
        );
      });
  }
}
