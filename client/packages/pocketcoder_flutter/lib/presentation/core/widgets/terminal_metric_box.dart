import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

/// A reusable metric display box for use in Row layouts.
///
/// Shows a label above a value, with optional accent color override.
/// Wraps itself in [Expanded] so it works directly inside a [Row].
class TerminalMetricBox extends StatelessWidget {
  final String label;
  final String value;

  /// Overrides the label and border accent color. Defaults to
  /// [ColorScheme.primary].
  final Color? accentColor;

  const TerminalMetricBox({
    super.key,
    required this.label,
    required this.value,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final accent = accentColor ?? colors.primary;

    return Expanded(
      child: Container(
        padding: EdgeInsets.all(AppSizes.space),
        decoration: BoxDecoration(
          border: Border.all(color: accent.withValues(alpha: 0.5)),
          color: accent.withValues(alpha: 0.05),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: accent,
                fontSize: AppSizes.fontMini,
                fontWeight: AppFonts.heavy,
                letterSpacing: 1,
              ),
            ),
            VSpace.x1,
            Text(
              value,
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: colors.onSurface,
                fontSize: AppSizes.fontBig,
                fontWeight: AppFonts.heavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
