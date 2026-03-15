import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/application/system/health_cubit.dart';
import 'package:pocketcoder_flutter/application/system/health_state.dart';
import "package:pocketcoder_flutter/domain/models/healthcheck.dart";
import 'package:pocketcoder_flutter/app/bootstrap.dart';

class SystemChecksScreen extends StatelessWidget {
  const SystemChecksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<HealthCubit>()..watchHealth(),
      child: UiFlowListener<HealthCubit, HealthState>(
        child: const _SystemChecksView(),
      ),
    );
  }
}

class _SystemChecksView extends StatelessWidget {
  const _SystemChecksView();

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.systemChecksTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: BiosFrame(
        title: context.l10n.systemChecksDiagnostics,
        child: BlocBuilder<HealthCubit, HealthState>(
          builder: (context, state) {
            return Column(
              children: [
                // Inline REFRESH button
                Padding(
                  padding: EdgeInsets.all(AppSizes.space),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TerminalButton(
                      label: context.l10n.actionRefresh,
                      onTap: () => context.read<HealthCubit>().refresh(),
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
    final colors = context.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.space * 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TerminalText(
            component,
            weight: TerminalTextWeight.heavy,
          ),
          TerminalText(
            '[$status]',
            color: isOk ? colors.primary : colors.error,
            weight: TerminalTextWeight.heavy,
          ),
        ],
      ),
    );
  }
}
