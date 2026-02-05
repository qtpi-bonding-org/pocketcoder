import 'package:flutter/material.dart';
import '../../../design_system/primitives/app_fonts.dart';
import '../../../design_system/primitives/app_palette.dart';
import '../../../design_system/primitives/app_sizes.dart';

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
    final effectiveColor = color ?? AppPalette.primary.textPrimary;
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
