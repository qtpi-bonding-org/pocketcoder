import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class AsciiLogo extends StatelessWidget {
  final String text;
  final Color? color;
  final double? fontSize;

  const AsciiLogo({
    super.key,
    required this.text,
    this.color,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final effectiveColor = color ?? colors.onSurface;
    final effectiveSize =
        fontSize ?? AppSizes.fontTiny; // Default to tiny for logo blocks

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: effectiveColor,
          fontSize: effectiveSize,
          height: 1.0,
          leadingDistribution: TextLeadingDistribution.even,
          fontWeight: AppFonts.heavy,
          fontFamily: AppFonts.bodyFamily,
          package: 'pocketcoder_flutter',
          shadows: [
            Shadow(
              color: effectiveColor.withValues(alpha: 0.5),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}
