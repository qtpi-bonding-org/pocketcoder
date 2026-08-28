import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';

sealed class CredentialConnectionStep {
  const CredentialConnectionStep();
}

class ApiKeyConnectionStep extends CredentialConnectionStep {
  const ApiKeyConnectionStep();
}

class BrowserVerificationConnectionStep extends CredentialConnectionStep {
  const BrowserVerificationConnectionStep({
    required this.verificationUri,
    required this.codeDestination,
    this.userCode,
    this.expiresAt,
  });

  final Uri verificationUri;
  final HarnessAuthCodeDestination codeDestination;
  final String? userCode;
  final DateTime? expiresAt;
}

/// A presentation-only credential connection panel. Orchestration belongs to
/// the adapter that supplies these callbacks.
class CredentialConnectionView extends StatelessWidget {
  const CredentialConnectionView({
    super.key,
    required this.step,
    required this.onOpenAuthorizationPage,
    required this.onCopyCode,
    required this.onSubmitCode,
    required this.onCancel,
    required this.onRetry,
  });

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
        userCode: final code?
      ) =>
        _deviceCode(context, code),
      BrowserVerificationConnectionStep(
        codeDestination: HarnessAuthCodeDestination.app
      ) =>
        _browserCode(context),
      BrowserVerificationConnectionStep(
        codeDestination: HarnessAuthCodeDestination.browser,
      ) =>
        _browserOnly(context),
      BrowserVerificationConnectionStep() => _actions(context),
    };
  }

  Widget _deviceCode(BuildContext context, String code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalText(code),
        TerminalButton(
          label: context.l10n.credentialConnectionCopy,
          onTap: () {
            onCopyCode(code);
            SystemChannels.platform.invokeMethod<void>(
              'Clipboard.setData',
              <String, dynamic>{'text': code},
            );
          },
        ),
        TerminalButton(
          label: context.l10n.credentialConnectionOpenAuthorizationPage,
          onTap: onOpenAuthorizationPage,
        ),
        TerminalText(context.l10n.credentialConnectionPasteCode),
        _actions(context),
      ],
    );
  }

  Widget _browserCode(BuildContext context) {
    return _BrowserCodeForm(
      onSubmitCode: onSubmitCode,
      openPage: onOpenAuthorizationPage,
      actions: _actions(context),
    );
  }

  Widget _browserOnly(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TerminalButton(
            label: context.l10n.credentialConnectionOpenAuthorizationPage,
            onTap: onOpenAuthorizationPage,
          ),
          _actions(context),
        ],
      );

  Widget _actions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TerminalButton(
          label: context.l10n.credentialConnectionCancel,
          isPrimary: false,
          onTap: onCancel,
        ),
        TerminalButton(
          label: context.l10n.credentialConnectionRetry,
          isPrimary: false,
          onTap: onRetry,
        ),
      ],
    );
  }
}

class _BrowserCodeForm extends StatefulWidget {
  const _BrowserCodeForm({
    required this.onSubmitCode,
    required this.openPage,
    required this.actions,
  });

  final ValueChanged<String> onSubmitCode;
  final VoidCallback openPage;
  final Widget actions;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalButton(
          label: context.l10n.credentialConnectionOpenAuthorizationPage,
          onTap: widget.openPage,
        ),
        TerminalText(context.l10n.credentialConnectionEnterCode),
        TerminalTextField(
          controller: _controller,
          label: context.l10n.harnessAuthOneTimeCode,
          onSubmitted: (_) => _submit(),
        ),
        TerminalButton(
          label: context.l10n.credentialConnectionSubmit,
          onTap: _submit,
        ),
        widget.actions,
      ],
    );
  }
}
