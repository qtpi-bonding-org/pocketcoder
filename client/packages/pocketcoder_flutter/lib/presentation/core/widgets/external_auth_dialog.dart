import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

import 'terminal_button.dart';
import 'terminal_dialog.dart';
import 'terminal_loading_indicator.dart';
import 'terminal_text.dart';
import 'terminal_text_field.dart';

/// Dumb presentation for an externally-owned authentication flow.
class ExternalAuthDialog extends StatelessWidget {
  const ExternalAuthDialog({
    super.key,
    required this.label,
    required this.isLoading,
    this.errorMessage,
    required this.onCancel,
    this.onRetry,
    this.challengeText,
    this.challengeTarget,
    this.onOpenChallenge,
    this.showCodeInput = false,
    this.onSubmitCode,
    this.isBusy = false,
  });

  final String label;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onCancel;
  final VoidCallback? onRetry;
  final String? challengeText;
  final String? challengeTarget;
  final VoidCallback? onOpenChallenge;
  final bool showCodeInput;
  final ValueChanged<String>? onSubmitCode;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final isError = errorMessage != null;
    return TerminalDialog(
      title: context.l10n.externalAuthTitle,
      content: isError
          ? _ErrorContent(label: label, message: errorMessage!)
          : _WaitingContent(
              label: label,
              isLoading: isLoading,
              challengeText: challengeText,
              challengeTarget: challengeTarget,
              onOpenChallenge: onOpenChallenge,
              showCodeInput: showCodeInput,
              onSubmitCode: onSubmitCode,
              isBusy: isBusy,
            ),
      actions: [
        if (isError && onRetry != null) ...[
          TerminalButton(label: context.l10n.externalAuthRetry, onTap: onRetry!),
          HSpace.x2,
        ],
        TerminalButton(
          label: context.l10n.externalAuthCancel,
          isPrimary: false,
          onTap: onCancel,
        ),
      ],
    );
  }
}

class _WaitingContent extends StatefulWidget {
  const _WaitingContent({
    required this.label,
    required this.isLoading,
    this.challengeText,
    this.challengeTarget,
    this.onOpenChallenge,
    required this.showCodeInput,
    this.onSubmitCode,
    required this.isBusy,
  });
  final String label;
  final bool isLoading;
  final String? challengeText;
  final String? challengeTarget;
  final VoidCallback? onOpenChallenge;
  final bool showCodeInput;
  final ValueChanged<String>? onSubmitCode;
  final bool isBusy;

  @override
  State<_WaitingContent> createState() => _WaitingContentState();
}

class _WaitingContentState extends State<_WaitingContent> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TerminalLoadingIndicator(label: widget.label),
          VSpace.x2,
          TerminalText(
            context.l10n.externalAuthConnecting(widget.label),
            textAlign: TextAlign.center,
            alpha: widget.isLoading ? 1 : 0.6,
          ),
          if (widget.challengeText != null) ...[
            VSpace.x2,
            TerminalText(widget.challengeText!, textAlign: TextAlign.center),
          ],
          if (widget.challengeTarget case final target? when target.isNotEmpty) ...[
            VSpace.x1,
            if (widget.onOpenChallenge != null)
              TerminalButton(
                label: context.l10n.onboardingOpenAuthorization,
                onTap: widget.onOpenChallenge!,
              ),
            VSpace.x1,
            SelectableText(target),
          ],
          if (widget.showCodeInput) ...[
            VSpace.x2,
            TerminalTextField(
              controller: _codeController,
              label: context.l10n.onboardingAuthorizationCode,
              hint: context.l10n.onboardingAuthorizationCodeHint,
              enabled: !widget.isBusy,
            ),
            VSpace.x2,
            TerminalButton(
              label: context.l10n.onboardingSubmitCode,
              isLoading: widget.isBusy,
              onTap: widget.onSubmitCode == null
                  ? () {}
                  : () => widget.onSubmitCode!(_codeController.text.trim()),
            ),
          ],
        ],
      );
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.label, required this.message});
  final String label;
  final String message;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TerminalText.label(label),
          VSpace.x2,
          TerminalText(message, color: context.colorScheme.error),
        ],
      );
}
