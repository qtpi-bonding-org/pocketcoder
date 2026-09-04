import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:flutter/services.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';

sealed class CredentialConnectionStep {
  const CredentialConnectionStep();
}

class ApiKeyConnectionStep extends CredentialConnectionStep {
  const ApiKeyConnectionStep();
}

class BrowserVerificationConnectionStep extends CredentialConnectionStep {
  const BrowserVerificationConnectionStep(
      {required this.verificationUri,
      required this.codeDestination,
      this.userCode,
      this.expiresAt});

  final Uri verificationUri;
  final HarnessAuthCodeDestination codeDestination;
  final String? userCode;
  final DateTime? expiresAt;
}

/// A presentation-only credential connection panel. Orchestration belongs to
/// the adapter that supplies these callbacks.
class CredentialConnectionView extends StatelessWidget {
  const CredentialConnectionView(
      {super.key,
      required this.step,
      required this.onOpenAuthorizationPage,
      required this.onCopyCode,
      required this.onSubmitCode,
      required this.onCancel,
      required this.onRetry});

  final CredentialConnectionStep step;
  final VoidCallback onOpenAuthorizationPage;
  final ValueChanged<String> onCopyCode;
  final ValueChanged<String> onSubmitCode;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      ApiKeyConnectionStep() => _actions(context),
      BrowserVerificationConnectionStep(
        codeDestination: HarnessAuthCodeDestination.browser,
        userCode: final code?,
        expiresAt: final expiresAt
      ) =>
        _deviceCode(context, code, expiresAt),
      BrowserVerificationConnectionStep(
        codeDestination: HarnessAuthCodeDestination.app,
        expiresAt: final expiresAt
      ) =>
        _browserCode(context, expiresAt),
      BrowserVerificationConnectionStep(
        codeDestination: HarnessAuthCodeDestination.browser,
        expiresAt: final expiresAt
      ) =>
        _browserOnly(context, expiresAt),
      BrowserVerificationConnectionStep() => _actions(context)
    };
  }

  Widget _expiryNotice(BuildContext context, DateTime? expiresAt) {
    if (expiresAt == null) return const SizedBox.shrink();
    return TerminalText(context.l10n.credentialConnectionExpiresAt(expiresAt),
        role: TextRole.body);
  }

  Widget _deviceCode(BuildContext context, String code, DateTime? expiresAt) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _expiryNotice(context, expiresAt),
      TerminalText(code, role: TextRole.body),
      TerminalButton(
          label: context.l10n.credentialConnectionCopy,
          onTap: () {
            onCopyCode(code);
            SystemChannels.platform.invokeMethod<void>(
                'Clipboard.setData', <String, dynamic>{'text': code});
          }),
      TerminalButton(
          label: context.l10n.credentialConnectionOpenAuthorizationPage,
          onTap: onOpenAuthorizationPage),
      TerminalText(context.l10n.credentialConnectionPasteCode,
          role: TextRole.body),
      _actions(context),
    ]);
  }

  Widget _browserCode(BuildContext context, DateTime? expiresAt) {
    return _BrowserCodeForm(
        onSubmitCode: onSubmitCode,
        openPage: onOpenAuthorizationPage,
        actions: _actions(context),
        expiryNotice: _expiryNotice(context, expiresAt));
  }

  Widget _browserOnly(BuildContext context, DateTime? expiresAt) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _expiryNotice(context, expiresAt),
        TerminalButton(
            label: context.l10n.credentialConnectionOpenAuthorizationPage,
            onTap: onOpenAuthorizationPage),
        _actions(context),
      ]);

  Widget _actions(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      TerminalButton(
          label: context.l10n.credentialConnectionCancel,
          kind: ActionKind.neutral,
          onTap: onCancel),
      TerminalButton(
          label: context.l10n.credentialConnectionRetry,
          kind: ActionKind.neutral,
          onTap: onRetry),
    ]);
  }
}

class _BrowserCodeForm extends StatefulWidget {
  const _BrowserCodeForm(
      {required this.onSubmitCode,
      required this.openPage,
      required this.actions,
      required this.expiryNotice});

  final ValueChanged<String> onSubmitCode;
  final VoidCallback openPage;
  final Widget actions;
  final Widget expiryNotice;

  @override
  State<_BrowserCodeForm> createState() => _BrowserCodeFormState();
}

class _BrowserCodeFormState extends State<_BrowserCodeForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) widget.onSubmitCode(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      widget.expiryNotice,
      TerminalButton(
          label: context.l10n.credentialConnectionOpenAuthorizationPage,
          onTap: widget.openPage),
      TerminalText(
        context.l10n.credentialConnectionEnterCode,
        role: TextRole.body,
      ),
      TerminalTextField(
          controller: _controller,
          label: context.l10n.harnessAuthOneTimeCode,
          onSubmitted: (_) => _submit()),
      TerminalButton(
          label: context.l10n.credentialConnectionSubmit, onTap: _submit),
      widget.actions,
    ]);
  }
}
