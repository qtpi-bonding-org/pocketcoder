import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_cubit.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_state.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_provider_console_link.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/terminal_command_card.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_confirm_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_status_glyph.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/server_control/widgets/connection_details.dart';
import 'package:pocketcoder_flutter/presentation/server_control/widgets/private_key_section.dart';
import 'package:pocketcoder_flutter/presentation/server_control/widgets/copy_button.dart';
import 'package:pocketcoder_flutter/presentation/server_control/widgets/provider_console_button.dart';
import 'package:pocketcoder_flutter/presentation/server_control/widgets/control_group_row.dart';
import 'package:pocketcoder_flutter/presentation/server_control/widgets/release_line.dart';

/// Confirm-dialog body text only; buttons use [_buttonLabel] instead.
String _localizedOperationLabel(
        BuildContext context, ServerControlOperation operation) =>
    switch (operation) {
      ServerControlOperation.restartPocketCoder =>
        context.l10n.serverControlOperationRestartPocketCoder,
      ServerControlOperation.updatePocketCoder =>
        context.l10n.serverControlOperationUpdatePocketCoder,
      ServerControlOperation.restartNixOs =>
        context.l10n.serverControlOperationRestartNixOs,
      ServerControlOperation.updateNixOs =>
        context.l10n.serverControlOperationUpdateNixOs,
      ServerControlOperation.saveBackup =>
        context.l10n.serverControlOperationSaveBackup,
      ServerControlOperation.restoreBackup =>
        context.l10n.serverControlOperationRestoreBackup
    };

class _ControlGrid extends StatelessWidget {
  const _ControlGrid({required this.state, required this.onRun});

  final ServerControlState state;
  final void Function(ServerControlOperation operation) onRun;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ControlGroupRow(
            groupLabel: context.l10n.serverControlGroupPocketCoder,
            left: ServerControlOperation.restartPocketCoder,
            right: ServerControlOperation.updatePocketCoder,
            disabled: state.isBusy,
            onRun: onRun),
        VSpace.x1,
        ControlGroupRow(
            groupLabel: context.l10n.serverControlGroupNixOs,
            left: ServerControlOperation.restartNixOs,
            right: ServerControlOperation.updateNixOs,
            disabled: state.isBusy,
            onRun: onRun),
        VSpace.x1,
        ControlGroupRow(
            groupLabel: context.l10n.serverControlGroupData,
            left: ServerControlOperation.saveBackup,
            right: ServerControlOperation.restoreBackup,
            disabled: state.isBusy,
            onRun: onRun),
      ]);
}

class ServerControlView extends StatelessWidget {
  const ServerControlView(
      {super.key,
      required this.instanceId,
      required this.inAppBrowserLauncher,
      this.providerConsoleLink});

  final String instanceId;
  final InAppBrowserLauncher inAppBrowserLauncher;

  /// Null in FOSS, which has no provider integration to link to -- the
  /// button below only renders when this is non-null.
  final IProviderConsoleLink? providerConsoleLink;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ServerControlCubit>();
    return BlocBuilder<ServerControlCubit, ServerControlState>(
        builder: (context, state) => PocketCoderShell(
            title: context.l10n.serverControlTitle,
            activePillar: NavPillar.manage,
            showBack: false,
            body: ListView(children: [
              if (state.connectionDetails case final details?
                  when details.isAvailable) ...[
                ConnectionDetails(details: details),
                VSpace.x2,
              ],
              ReleaseLine(state: state),
              VSpace.x2,
              if (providerConsoleLink case final link?) ...[
                ProviderConsoleButton(
                    link: link, launcher: inAppBrowserLauncher),
                VSpace.x2,
              ],
              if (state.publicKey case final publicKey?) ...[
                Text(context.l10n.serverControlPublicKeyLabel),
                VSpace.x1,
                Row(children: [
                  Expanded(child: SelectableText(publicKey)),
                  CopyButton(value: publicKey),
                ]),
                VSpace.x2,
                PrivateKeySection(instanceId: instanceId, state: state),
                VSpace.x2,
              ],
              _ControlGrid(
                  state: state,
                  onRun: (operation) => _confirm(
                      context,
                      operation,
                      () => cubit.run(
                          operation: operation, instanceId: instanceId))),
              if (state.error case final error?)
                TerminalText(
                    context.l10n.serverControlErrorPrefix(error.toString()),
                    role: TextRole.warn),
              if (state.result case final result?) ...[
                VSpace.x2,
                TerminalCommandCard(
                    command: state.operation?.name ?? 'server-control',
                    status: result.succeeded
                        ? TerminalStatus.success
                        : TerminalStatus.failure,
                    outputLabel: context.l10n.serverControlOutputLabel,
                    output: _output(result.stdout, result.stderr)),
              ],
            ])));
  }

  Future<void> _confirm(BuildContext context, ServerControlOperation operation,
      VoidCallback onConfirm) async {
    final isRestore = operation == ServerControlOperation.restoreBackup;
    final confirmed = await showTerminalConfirmDialog(context,
        title: isRestore
            ? context.l10n.serverControlConfirmRestoreTitle
            : context.l10n.serverControlConfirmTitle,
        body: isRestore
            ? context.l10n.serverControlConfirmRestoreBody
            : context.l10n.serverControlConfirmBody(
                _localizedOperationLabel(context, operation)),
        cancelLabel: context.l10n.serverControlConfirmCancel,
        confirmLabel: context.l10n.serverControlConfirmConfirm,
        danger: isRestore);
    if (confirmed == true && context.mounted) onConfirm();
  }

  String _output(String stdout, String stderr) =>
      stderr.isEmpty ? stdout : '$stdout\nSTDERR\n$stderr';
}
