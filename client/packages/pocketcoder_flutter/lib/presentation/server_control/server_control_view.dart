import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_cubit.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_state.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_provider_console_link.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_connection_details_provider.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/terminal_command_card.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_status_glyph.dart';

String _localizedOperationLabel(
  BuildContext context,
  ServerControlOperation operation,
) =>
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
    };

class ServerControlView extends StatelessWidget {
  const ServerControlView({
    super.key,
    required this.instanceId,
    required this.inAppBrowserLauncher,
    this.providerConsoleLink,
  });

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
        body: ListView(
          children: [
            if (state.connectionDetails case final details?
                when details.isAvailable) ...[
              _ConnectionDetails(details: details),
              VSpace.x2,
            ],
            _ReleaseLine(state: state),
            VSpace.x2,
            if (providerConsoleLink case final link?) ...[
              _ProviderConsoleButton(link: link, launcher: inAppBrowserLauncher),
              VSpace.x2,
            ],
            if (state.publicKey case final publicKey?) ...[
              Text(context.l10n.serverControlPublicKeyLabel),
              VSpace.x1,
              Row(
                children: [
                  Expanded(child: SelectableText(publicKey)),
                  IconButton(
                    tooltip: context.l10n.serverControlCopy,
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: publicKey));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.serverControlCopied)),
                        );
                      }
                    },
                  ),
                ],
              ),
              VSpace.x2,
              _PrivateKeySection(instanceId: instanceId, state: state),
              VSpace.x2,
            ],
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
        title: Text(context.l10n.serverControlConfirmTitle),
        content: Text(
          context.l10n.serverControlConfirmBody(
            _localizedOperationLabel(context, operation),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.serverControlConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.serverControlConfirmConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) onConfirm();
  }

  String _output(String stdout, String stderr) =>
      stderr.isEmpty ? stdout : '$stdout\nSTDERR\n$stderr';
}

class _ConnectionDetails extends StatefulWidget {
  const _ConnectionDetails({required this.details});

  final IServerConnectionDetailsProvider details;

  @override
  State<_ConnectionDetails> createState() => _ConnectionDetailsState();
}

class _ConnectionDetailsState extends State<_ConnectionDetails> {
  bool _showPassword = false;

  Future<void> _toggleShowPassword(BuildContext context) async {
    if (_showPassword) {
      setState(() => _showPassword = false);
      return;
    }
    final approved = await context.read<ServerControlCubit>().confirmLocalAuth(
          reason: context.l10n.serverControlLocalAuthReason,
        );
    if (approved && mounted) setState(() => _showPassword = true);
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.serverControlConnectionDetails,
            style: TextStyle(
              color: context.colorScheme.primary,
              fontFamily: AppFonts.bodyFamily,
              fontSize: AppSizes.fontSmall,
            )),
        VSpace.x1,
        if (details.ipAddress case final value?)
          _DetailRow(label: context.l10n.serverControlIpAddress, value: value),
        if (details.httpsEndpoint case final value?)
          _DetailRow(
              label: context.l10n.serverControlHttpsEndpoint, value: value),
        if (details.adminIdentity case final value?)
          _DetailRow(
              label: context.l10n.serverControlAdminIdentity, value: value),
        if (details.adminPassword case final value?)
          _DetailRow(
            label: context.l10n.serverControlAdminPassword,
            value: _showPassword ? value : '•' * value.length,
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TerminalButton(
                  label: _showPassword
                      ? context.l10n.serverControlHide
                      : context.l10n.serverControlShow,
                  isPrimary: false,
                  onTap: () => _toggleShowPassword(context),
                ),
                HSpace.x1,
                _CopyButton(value: value),
              ],
            ),
          ),
      ],
    );
  }
}

class _PrivateKeySection extends StatefulWidget {
  const _PrivateKeySection({required this.instanceId, required this.state});

  final String instanceId;
  final ServerControlState state;

  @override
  State<_PrivateKeySection> createState() => _PrivateKeySectionState();
}

class _PrivateKeySectionState extends State<_PrivateKeySection> {
  bool _revealed = false;

  Future<void> _toggleReveal(BuildContext context) async {
    if (_revealed) {
      setState(() => _revealed = false);
      return;
    }
    final cubit = context.read<ServerControlCubit>();
    await cubit.revealPrivateKey(
      instanceId: widget.instanceId,
      authReason: context.l10n.serverControlLocalAuthReason,
    );
    if (mounted && cubit.state.privateKey != null) {
      setState(() => _revealed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final privateKey = widget.state.privateKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.serverControlPrivateKeyLabel),
        VSpace.x1,
        if (_revealed && privateKey != null)
          Row(
            children: [
              Expanded(child: SelectableText(privateKey)),
              _CopyButton(value: privateKey),
            ],
          )
        else
          const SizedBox.shrink(),
        VSpace.x1,
        TerminalButton(
          label: _revealed
              ? context.l10n.serverControlHide
              : context.l10n.serverControlShow,
          isPrimary: false,
          onTap: () => _toggleReveal(context),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.action});

  final String label;
  final String value;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: AppSizes.space),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text('$label\n$value')),
            action ?? _CopyButton(value: value),
          ],
        ),
      );
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: context.l10n.serverControlCopy,
        icon: const Icon(Icons.copy),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.serverControlCopied)),
            );
          }
        },
      );
}

class _ProviderConsoleButton extends StatelessWidget {
  const _ProviderConsoleButton({required this.link, required this.launcher});

  final IProviderConsoleLink link;
  final InAppBrowserLauncher launcher;

  @override
  Widget build(BuildContext context) => TerminalButton(
        label: context.l10n.serverControlProviderConsole,
        isPrimary: false,
        onTap: () async {
          final uri = await link.resolve();
          if (!context.mounted) return;
          if (uri == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(context.l10n.serverControlProviderConsoleUnavailable),
              ),
            );
            return;
          }
          await launcher.open(uri);
        },
      );
}

class _ReleaseLine extends StatelessWidget {
  const _ReleaseLine({required this.state});

  final ServerControlState state;

  @override
  Widget build(BuildContext context) {
    final release = state.release;
    return Text(
      release == null ? context.l10n.serverControlReleaseChecking : _lines(context, release),
      style: TextStyle(
        color: context.colorScheme.primary,
        fontFamily: AppFonts.bodyFamily,
        fontSize: AppSizes.fontSmall,
      ),
    );
  }

  String _lines(BuildContext context, ServerReleaseStatusSnapshot release) {
    final lines = [
      context.l10n.serverControlReleaseStatus(release.status.name.toUpperCase()),
      context.l10n.serverControlReleaseCurrent(release.currentVersion),
      if (release.availableVersion case final available?)
        context.l10n.serverControlReleaseAvailable(available),
      if (release.appContractVersion case final app?)
        if (release.serverApiVersion case final server?)
          if (release.deploymentContractVersion case final deployment?)
            context.l10n.serverControlReleaseContracts(
              app.toString(),
              server.toString(),
              deployment.toString(),
            ),
    ];
    return lines.join('\n');
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
          child: Text(
            _localizedOperationLabel(context, operation).toUpperCase(),
          ),
        ),
      );
}
