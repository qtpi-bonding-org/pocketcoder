import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class TerminalButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? color;
  final bool isLoading;

  final bool filled;

  const TerminalButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isPrimary = true,
    this.color,
    this.isLoading = false,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final accentColor =
        color ?? (isPrimary ? colors.primary : colors.onSurface);
    final textColor = filled ? colors.surface : accentColor;
    final bgColor = filled ? accentColor : Colors.transparent;

    return InkWell(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.space * 2,
          vertical: AppSizes.space,
        ),
        decoration: BoxDecoration(
          color: isLoading ? bgColor.withValues(alpha: 0.5) : bgColor,
          border: Border.all(
            color: accentColor,
            width: AppSizes.borderWidth,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: AppSizes.progressIndicatorSize,
                height: AppSizes.progressIndicatorSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              ),
              HSpace.x2,
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  fontFamily: AppFonts.family,
                  color: textColor,
                  fontSize: AppSizes.fontBody,
                  fontWeight: AppFonts.heavy,
                  package: 'pocketcoder_flutter',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
