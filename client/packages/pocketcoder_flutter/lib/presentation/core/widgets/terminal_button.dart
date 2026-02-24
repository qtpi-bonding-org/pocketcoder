import 'package:flutter/material.dart';
import '../../../design_system/theme/app_theme.dart';

class TerminalButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? color;
  final bool isLoading;

  const TerminalButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isPrimary = true,
    this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final accentColor =
        color ?? (isPrimary ? colors.primary : colors.onSurface);
    final textColor = colors.surface; // True Black
    final bgColor = accentColor;

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
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              ),
              HSpace.x2,
            ],
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: textColor,
                fontSize: AppSizes.fontTiny,
                fontWeight: AppFonts.heavy,
                package: 'pocketcoder_flutter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
