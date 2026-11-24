import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';

class ErrorInboxLink extends StatelessWidget {
  const ErrorInboxLink({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.center,
        child: TerminalButton(
          label: context.l10n.errorsInboxLink(count),
          onTap: onTap,
        ),
      );
}
