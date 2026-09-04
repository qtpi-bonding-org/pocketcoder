import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/decision_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/service_line.dart';
import 'package:pocketcoder_flutter/design_system/primitives/status_marker.dart';
import 'package:pocketcoder_flutter/application/system/health_state.dart';
import "package:pocketcoder_flutter/domain/models/healthcheck.dart";

class SystemChecksView extends StatelessWidget {
  const SystemChecksView(
      {super.key, required this.state, required this.onRefresh});

  final HealthState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
        title: context.l10n.systemChecksTitle.toLowerCase(),
        activePillar: NavPillar.config,
        showBack: true,
        body: DecisionFrame(
            title: context.l10n.systemChecksDiagnostics.toLowerCase(),
            child: Builder(builder: (context) {
              return Column(children: [
                Padding(
                    padding: EdgeInsets.all(AppSizes.space),
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: TerminalButton(
                            label: context.l10n.actionRefresh,
                            onTap: onRefresh))),
                Expanded(
                    child: state.checks.isEmpty && !state.isLoading
                        ? Center(
                            child: TerminalText(
                              context.l10n.systemChecksEmpty,
                              role: TextRole.body,
                            ),
                          )
                        : ListView.builder(
                            itemCount: state.checks.length,
                            itemBuilder: (context, index) {
                              final check = state.checks[index];
                              return _buildCheckRow(context,
                                  check.name.toUpperCase(), check.status);
                            })),
              ]);
            })));
  }

  Widget _buildCheckRow(
      BuildContext context, String component, HealthcheckStatus status) {
    final marker = switch (status) {
      HealthcheckStatus.ready => StatusMarker.ok,
      HealthcheckStatus.starting ||
      HealthcheckStatus.degraded =>
        StatusMarker.attention,
      HealthcheckStatus.offline ||
      HealthcheckStatus.error ||
      HealthcheckStatus.unknown =>
        StatusMarker.failed,
    };
    return ServiceLine(name: component, status: marker);
  }
}
