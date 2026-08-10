import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'terminal_status_glyph.dart';

class TerminalLoadingIndicator extends StatelessWidget {
  final String? label;

  const TerminalLoadingIndicator({
    super.key,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TerminalStatusGlyph(
          status: TerminalStatus.running,
          fontSize: AppSizes.fontLarge,
        ),
        if (label != null) ...[
          VSpace.x1,
          Text(
            '[ ${label?.toUpperCase() ?? ''} ]',
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: colors.secondary,
              fontSize: AppSizes.fontTiny,
              package: 'pocketcoder_flutter',
            ),
          ),
        ],
      ],
    );
  }
}
