import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class TerminalHeader extends StatelessWidget {
  final String title;

  const TerminalHeader({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontFamily: AppFonts.headerFamily,
            color: colors.onSurface,
            fontSize: AppSizes.fontBig,
            fontWeight: AppFonts.heavy,
            letterSpacing: 2,
            package: 'pocketcoder_flutter',
          ),
          textAlign: TextAlign.center,
        ),
        VSpace.x1,
        Container(
          height: AppSizes.borderWidth,
          color: colors.onSurface.withValues(alpha: 0.3),
        ),
      ],
    );
  }
}
