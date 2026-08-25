import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

import 'terminal_button.dart';
import 'terminal_dialog.dart';
import 'terminal_loading_indicator.dart';
import 'terminal_text.dart';

/// A presentation-only dialog for an authentication flow owned by its caller.
///
/// This widget deliberately knows nothing about the authentication mechanism
/// or its controller. The caller supplies the current state and callbacks and
/// is responsible for dismissing the dialog when authentication succeeds.
class ExternalAuthDialog extends StatelessWidget {
  /// The provider or agent currently being authenticated.
  final String label;

  /// Whether the external authentication request is still in progress.
  ///
  /// An [errorMessage] takes precedence when present, so callers can safely
  /// render a failure while retaining their last loading value.
  final bool isLoading;

  /// A user-facing failure message. When non-null, the dialog renders its
  /// error state instead of the connecting state.
  final String? errorMessage;

  /// Called when the user cancels or dismisses the flow.
  final VoidCallback onCancel;

  /// Called when the user requests another authentication attempt. If null,
  /// no retry action is shown.
  final VoidCallback? onRetry;

  const ExternalAuthDialog({
    super.key,
    required this.label,
    required this.isLoading,
    this.errorMessage,
    required this.onCancel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isError = errorMessage != null;

    return TerminalDialog(
      title: context.l10n.externalAuthTitle,
      content: isError
          ? _ErrorContent(
              label: label,
              message: errorMessage!,
            )
          : _WaitingContent(label: label, isLoading: isLoading),
      actions: [
        if (isError && onRetry != null) ...[
          TerminalButton(
            label: context.l10n.externalAuthRetry,
            onTap: onRetry!,
          ),
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

class _WaitingContent extends StatelessWidget {
  final String label;
  final bool isLoading;

  const _WaitingContent({required this.label, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TerminalLoadingIndicator(label: label),
        VSpace.x2,
        TerminalText(
          context.l10n.externalAuthConnecting(label),
          textAlign: TextAlign.center,
          alpha: isLoading ? 1 : 0.6,
        ),
      ],
    );
  }
}

class _ErrorContent extends StatelessWidget {
  final String label;
  final String message;

  const _ErrorContent({required this.label, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalText.label(label),
        VSpace.x2,
        TerminalText(
          message,
          color: colors.error,
        ),
      ],
    );
  }
}
