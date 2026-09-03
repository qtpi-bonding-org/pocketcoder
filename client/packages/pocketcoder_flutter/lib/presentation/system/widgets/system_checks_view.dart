import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/application/system/health_state.dart';
import "package:pocketcoder_flutter/domain/models/healthcheck.dart";

class SystemChecksView extends StatelessWidget {
  const SystemChecksView({
    super.key,
    required this.state,
    required this.onRefresh,
  });

  final HealthState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.systemChecksTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: BiosFrame(
        title: context.l10n.systemChecksDiagnostics,
        child: Builder(
          builder: (context) {
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(AppSizes.space),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TerminalButton(
                      label: context.l10n.actionRefresh,
                      onTap: onRefresh,
                    ),
                  ),
                ),
                Expanded(
                  child: state.checks.isEmpty && !state.isLoading
                      ? Center(
                          child: TerminalText(
                            context.l10n.systemChecksEmpty,
                            alpha: 0.5,
                          ),
                        )
                      : ListView.builder(
                          itemCount: state.checks.length,
                          itemBuilder: (context, index) {
                            final check = state.checks[index];
                            return _buildCheckRow(
                              context,
                              check.name.toUpperCase(),
                              check.status.name.toUpperCase(),
                              check.status == HealthcheckStatus.ready,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCheckRow(
    BuildContext context,
    String component,
    String status,
    bool isOk,
  ) {
    return BiosRow(
      label: component,
      value: '[$status]',
      isDestructive: !isOk,
    );
  }
}
