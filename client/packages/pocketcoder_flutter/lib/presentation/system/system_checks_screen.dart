import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/scanline_widget.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/application/system/health_cubit.dart';
import 'package:pocketcoder_flutter/application/system/health_state.dart';
import 'package:pocketcoder_flutter/domain/models/healthcheck.dart';
import 'package:go_router/go_router.dart';
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
    final colors = context.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: ScanlineWidget(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSizes.space * 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TerminalHeader(title: 'SYSTEM CHECKS'),
                VSpace.x2,
                Expanded(
                  child: BiosFrame(
                    title: 'SYSTEM DIAGNOSTICS',
                    child: BlocBuilder<HealthCubit, HealthState>(
                      builder: (context, state) {
                        if (state.checks.isEmpty && !state.isLoading) {
                          return Center(
                            child: Text(
                              'NO DIAGNOSTICS AVAILABLE',
                              style: TextStyle(
                                color: colors.onSurface.withValues(alpha: 0.5),
                                fontFamily: AppFonts.bodyFamily,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
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
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: TerminalFooter(
        actions: [
          TerminalAction(
            label: 'BACK',
            onTap: () => context.pop(),
          ),
          TerminalAction(
            label: 'REFRESH',
            onTap: () => context.read<HealthCubit>().refresh(),
          ),
        ],
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
          Text(
            component,
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: colors.onSurface,
              fontWeight: AppFonts.heavy,
            ),
          ),
          Text(
            '[$status]',
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: isOk ? colors.primary : colors.error,
              fontWeight: AppFonts.heavy,
            ),
          ),
        ],
      ),
    );
  }
}
