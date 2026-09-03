import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';

class TerminalDialogActions extends StatelessWidget {
  const TerminalDialogActions({
    super.key,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel,
    this.onCancel,
    this.confirmEnabled = true,
    this.destructive = false,
  });

  final String confirmLabel;
  final VoidCallback? onConfirm;
  final String? cancelLabel;
  final VoidCallback? onCancel;
  final bool confirmEnabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final cancelColor = emphasize(colors.onSurface, Emphasis.outlined).text;
    final confirmColor = emphasize(
      destructive ? AppPalette.primary.destructiveColor : colors.primary,
      Emphasis.outlined,
    ).text;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cancelLabel != null) ...[
          TerminalButton(
            label: cancelLabel!,
            isPrimary: false,
            color: cancelColor,
            filled: false,
            onTap: onCancel ?? () {},
          ),
          HSpace.x2,
        ],
        TerminalButton(
          label: confirmLabel,
          color: confirmColor,
          filled: false,
          onTap: confirmEnabled ? (onConfirm ?? () {}) : () {},
        ),
      ],
    );
  }
}
