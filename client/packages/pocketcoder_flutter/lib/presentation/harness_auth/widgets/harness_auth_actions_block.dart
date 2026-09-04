import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/harness_auth/widgets/credential_connection_view.dart';

class HarnessAuthActionsBlock extends StatelessWidget {
  const HarnessAuthActionsBlock({
    super.key,
    required this.harness,
    required this.status,
    required this.edges,
    required this.codeController,
    required this.isBusy,
    required this.onStartAccount,
    required this.onUseApiKey,
    required this.onSubmit,
    required this.onCancel,
    required this.onDisconnect,
    required this.onRefresh,
    required this.onOpenAuthorizationPage,
    required this.onCopyCode});

  final Harnesse harness;
  final HarnessAuthStatus status;
  final List<HarnessProvider> edges;
  final TextEditingController codeController;
  final bool isBusy;
  final void Function(String) onStartAccount;
  final VoidCallback onUseApiKey;
  final Future<void> Function(String) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback onDisconnect;
  final VoidCallback onRefresh;
  final void Function(Uri) onOpenAuthorizationPage;
  final ValueChanged<String> onCopyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
      if (status.challenge case final challenge?)
        _connectionView(context, challenge),
      VSpace.x2,
      _actions(context),
      VSpace.x2,
      TerminalButton(
          label: l10n.harnessAuthRefresh,
          isPrimary: false,
          filled: false,
          isLoading: isBusy,
          onTap: isBusy ? () {} : onRefresh),
      if (status.attempt case final attempt?)
        Padding(
            padding: EdgeInsets.only(top: AppSizes.space),
            child: TerminalText(l10n.harnessAuthAttempt(attempt.id)), role: TextRole.body)
    ]);
  }

  Widget _connectionView(
      BuildContext context, HarnessAuthChallenge challenge) {
    final uri = challenge.verificationUri;
    final destination = challenge.codeDestination;
    if (uri == null ||
        (destination != HarnessAuthCodeDestination.browser &&
            destination != HarnessAuthCodeDestination.app)) {
      return TerminalText(challenge.legacyText ?? challenge.text, role: TextRole.body)
    }
    return CredentialConnectionView(
      step: BrowserVerificationConnectionStep(
        verificationUri: uri,
        codeDestination: destination,
        userCode: challenge.userCode,
        expiresAt: challenge.expiresAt),
      onOpenAuthorizationPage: () => onOpenAuthorizationPage(uri),
      onCopyCode: onCopyCode,
      onSubmitCode: _submit,
      onCancel: onCancel,
      onRetry: () => onStartAccount(status.provider));
  }

  Widget _actions(BuildContext context) {
    if (status.isDisconnected) {
      final oauthEdges =
          edges.where((edge) => edge.supportsOauth == true).toList();
      final actionButtons = oauthEdges.isNotEmpty
          ? [
              for (final edge in oauthEdges)
                TerminalButton(
                    label: context.l10n.harnessAuthAccountLogin,
                    onTap: isBusy ? () {} : () => onStartAccount(edge.provider),
                    filled: false,
                    isLoading: isBusy),
            ]
          : edges.isNotEmpty
              ? [
                  TerminalButton(
                      label: context.l10n.providerScreenAddKey,
                      onTap: isBusy ? () {} : onUseApiKey,
                      filled: false,
                      isLoading: isBusy),
                ]
              : const <Widget>[];
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < actionButtons.length; i++) ...[
              if (i > 0) VSpace.x1,
              actionButtons[i],
            ],
          ]);
    }
    if (status.isConnected) {
      return TerminalButton(
          label: context.l10n.harnessAuthDisconnect,
          onTap: isBusy ? () {} : onDisconnect,
          filled: false,
          isLoading: isBusy);
    }
    return TerminalButton(
        label: context.l10n.harnessAuthCancel,
        onTap: isBusy ? () {} : onCancel,
        filled: false,
        isLoading: isBusy);
  }

  Future<void> _submit(String code) async {
    final value = code.trim();
    if (value.isEmpty || isBusy) {
      return;
    }
    await onSubmit(value);
    codeController.clear();
  }
}
