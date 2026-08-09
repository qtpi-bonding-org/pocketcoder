import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_pro/application/server_update/server_update_cubit.dart';
import 'package:pocketcoder_pro/infrastructure/server_update/current_instance_store.dart';

import 'adapters/update_server_adapter.dart';

/// User-initiated server update: SSH in as root, run
/// `git pull && docker compose --profile harness-images build && docker compose up -d`, show the
/// real output. Nothing happens until the user taps UPDATE -- no
/// background timer, no auto-polling, no silent updates.
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
      future: getIt<CurrentInstanceStore>().read(),
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
      create: (_) => getIt<ServerUpdateCubit>(),
      child: UpdateServerAdapter(instanceId: resolvedInstanceId),
    );
  }
}
