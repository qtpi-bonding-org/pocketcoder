import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'terminal_status_glyph.dart';

class TerminalLoadingIndicator extends StatelessWidget {
  final String? label;
  final TerminalStatus status;

  const TerminalLoadingIndicator({
    super.key,
    this.label,
    this.status = TerminalStatus.running,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TerminalStatusGlyph(
          status: status,
          fontSize: AppSizes.fontBody,
        ),
        if (label != null) ...[
          VSpace.x1,
          Text(
            '[ ${label?.toUpperCase() ?? ''} ]',
            style: TextStyle(
              fontFamily: AppFonts.family,
              color: colors.secondary,
              fontSize: AppSizes.fontBody,
              package: 'pocketcoder_flutter',
            ),
          ),
        ],
      ],
    );
  }
}
