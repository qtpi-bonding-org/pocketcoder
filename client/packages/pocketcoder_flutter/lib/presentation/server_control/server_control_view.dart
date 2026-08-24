import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_cubit.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/terminal_command_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_status_glyph.dart';

class ServerControlView extends StatelessWidget {
  const ServerControlView({
    super.key,
    required this.instanceId,
  });

  final String instanceId;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ServerControlCubit>();
    return BlocBuilder<ServerControlCubit, ServerControlState>(
      builder: (context, state) => PocketCoderShell(
        title: 'SERVER CONTROLS',
        activePillar: NavPillar.configure,
        showBack: true,
        body: ListView(
          children: [
            _ReleaseLine(state: state),
            VSpace.x2,
            for (final operation in ServerControlOperation.values)
              Padding(
                padding: EdgeInsets.only(bottom: AppSizes.space),
                child: _ControlButton(
                  operation: operation,
                  disabled: state.isBusy,
                  onPressed: () => _confirm(
                    context,
                    operation,
                    () => cubit.run(
                      operation: operation,
                      instanceId: instanceId,
                    ),
                  ),
                ),
              ),
            if (state.error case final error?)
              Text(
                'ERROR: $error',
                style: TextStyle(color: context.terminalColors.warning),
              ),
            if (state.result case final result?) ...[
              VSpace.x2,
              TerminalCommandCard(
                command: state.operation?.name ?? 'server-control',
                status: result.succeeded
                    ? TerminalStatus.success
                    : TerminalStatus.failure,
                outputLabel: 'OUTPUT',
                output: _output(result.stdout, result.stderr),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    ServerControlOperation operation,
    VoidCallback onConfirm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CONFIRM SERVER CONTROL'),
        content: Text('${_label(operation)} will run on your server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) onConfirm();
  }

  String _output(String stdout, String stderr) =>
      stderr.isEmpty ? stdout : '$stdout\nSTDERR\n$stderr';

  static String _label(ServerControlOperation operation) => switch (operation) {
        ServerControlOperation.restartPocketCoder => 'Restart PocketCoder',
        ServerControlOperation.updatePocketCoder => 'Update PocketCoder',
        ServerControlOperation.restartNixOs => 'Restart NixOS',
        ServerControlOperation.updateNixOs => 'Update NixOS',
        ServerControlOperation.saveBackup => 'Save backup',
      };
}

class _ReleaseLine extends StatelessWidget {
  const _ReleaseLine({required this.state});

  final ServerControlState state;

  @override
  Widget build(BuildContext context) {
    final release = state.release;
    return Text(
      release == null
          ? 'RELEASE STATUS: CHECKING'
          : 'RELEASE STATUS: ${release.status.name.toUpperCase()}\n'
              'CURRENT: ${release.currentVersion}',
      style: TextStyle(
        color: context.colorScheme.primary,
        fontFamily: AppFonts.bodyFamily,
        fontSize: AppSizes.fontSmall,
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.operation,
    required this.disabled,
    required this.onPressed,
  });

  final ServerControlOperation operation;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: disabled ? null : onPressed,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(operation.name
              .replaceAllMapped(
                RegExp(r'([A-Z])'),
                (match) => ' ${match.group(1)}',
              )
              .toUpperCase()),
        ),
      );
}
