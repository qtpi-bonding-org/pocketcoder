import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class AsciiLogo extends StatelessWidget {
  final String text;
  final Color? color;
  final double? fontSize;
  final Alignment alignment;

  const AsciiLogo({
    super.key,
    required this.text,
    this.color,
    this.fontSize,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final effectiveColor = color ?? colors.onSurface;
    final effectiveSize =
        fontSize ?? AppSizes.fontBody; // Default to tiny for logo blocks

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        style: TextStyle(
          color: effectiveColor,
          fontSize: effectiveSize,
          height: 1.0,
          leadingDistribution: TextLeadingDistribution.even,
          fontWeight: AppFonts.heavy,
          fontFamily: AppFonts.family,
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
