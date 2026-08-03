import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';

import 'package:pocketcoder_pro/application/server_update/server_update_cubit.dart';
import 'package:pocketcoder_pro/application/server_update/server_update_message_mapper.dart';
import 'package:pocketcoder_pro/application/server_update/server_update_state.dart';
import 'package:pocketcoder_pro/domain/server_update/server_update_result.dart';
import 'package:pocketcoder_pro/infrastructure/server_update/current_instance_store.dart';

/// User-initiated server update: SSH in as root, run
/// `git pull && docker compose --profile harness-images build && docker compose up -d`, show the
/// real output. Nothing happens until the user taps UPDATE -- no
/// background timer, no auto-polling, no silent updates.
///
/// [instanceId] is optional: passed directly right after a fresh deploy
/// (from DetailsScreen), or resolved from [CurrentInstanceStore] when
/// reached later from Settings with no known instance in the nav stack.
class UpdateServerScreen extends StatelessWidget {
  final String? instanceId;

  const UpdateServerScreen({super.key, this.instanceId});

  @override
  Widget build(BuildContext context) {
    final directId = instanceId;
    if (directId != null && directId.isNotEmpty) {
      return _buildFlow(directId);
    }

    return FutureBuilder<String?>(
      future: GetIt.I<CurrentInstanceStore>().read(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalScaffold(
            title: 'SERVER UPDATE',
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final resolvedId = snapshot.data;
        if (resolvedId == null || resolvedId.isEmpty) {
          return TerminalScaffold(
            title: 'SERVER UPDATE',
            actions: [
              TerminalAction(
                label: 'DISMISS',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
            body: const Center(
              child: Text('NO DEPLOYMENT FOUND ON THIS DEVICE.'),
            ),
          );
        }

        return _buildFlow(resolvedId);
      },
    );
  }

  Widget _buildFlow(String resolvedInstanceId) {
    return BlocProvider(
      create: (_) => GetIt.I<ServerUpdateCubit>(),
      child: UiFlowListener<ServerUpdateCubit, ServerUpdateState>(
        mapper: GetIt.I<ServerUpdateMessageMapper>(),
        child: _UpdateServerView(instanceId: resolvedInstanceId),
      ),
    );
  }
}

class _UpdateServerView extends StatelessWidget {
  final String instanceId;

  const _UpdateServerView({required this.instanceId});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final cubit = context.read<ServerUpdateCubit>();

    return BlocBuilder<ServerUpdateCubit, ServerUpdateState>(
      builder: (context, state) {
        return TerminalScaffold(
          title: 'SERVER UPDATE',
          actions: [
            TerminalAction(
              label: 'DISMISS',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BiosFrame(
                  title: 'UPDATE SEQUENCE',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'cd /opt/pocketcoder && git pull && '
                        'docker compose --profile harness-images build && '
                        'docker compose up -d',
                        style: TextStyle(
                          fontFamily: AppFonts.bodyFamily,
                          color: colors.onSurface.withValues(alpha: 0.7),
                          fontSize: AppSizes.fontSmall,
                        ),
                      ),
                      VSpace.x1,
                      Text(
                        'RUNS OVER SSH AS ROOT. NOTHING HAPPENS UNTIL YOU TAP UPDATE.',
                        style: TextStyle(
                          fontFamily: AppFonts.bodyFamily,
                          color: colors.onSurface.withValues(alpha: 0.5),
                          fontSize: AppSizes.fontTiny,
                        ),
                      ),
                    ],
                  ),
                ),
                VSpace.x2,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        state.isLoading ? null : () => cubit.update(instanceId),
                    child: Text(state.isLoading ? 'UPDATING...' : 'UPDATE'),
                  ),
                ),
                if (state.result != null) ...[
                  VSpace.x2,
                  _buildResultBanner(state.result!, colors),
                  VSpace.x2,
                  BiosFrame(
                    title: 'OUTPUT',
                    child: SelectableText(
                      _combinedOutput(state.result!),
                      style: TextStyle(
                        fontFamily: AppFonts.bodyFamily,
                        color: colors.onSurface,
                        fontSize: AppSizes.fontTiny,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultBanner(ServerUpdateResult result, ColorScheme colors) {
    final succeeded = result.succeeded;
    final color = succeeded ? Colors.green : colors.error;
    return Container(
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
      ),
      child: Text(
        succeeded
            ? 'UPDATE SUCCEEDED (EXIT 0)'
            : 'UPDATE FAILED (EXIT ${result.exitCode})',
        style: TextStyle(
          fontFamily: AppFonts.bodyFamily,
          color: color,
          fontWeight: AppFonts.heavy,
          fontSize: AppSizes.fontStandard,
        ),
      ),
    );
  }

  String _combinedOutput(ServerUpdateResult result) {
    if (result.stderr.isEmpty) return result.stdout;
    return '${result.stdout}\n--- stderr ---\n${result.stderr}';
  }
}
