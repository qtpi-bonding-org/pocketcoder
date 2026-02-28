import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class BiosListTile extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isDestructive;
  final bool hasBadge;

  const BiosListTile({
    super.key,
    required this.label,
    this.value,
    required this.onTap,
    this.isSelected = false,
    this.isDestructive = false,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;

    final textColor = isSelected
        ? colors.surface
        : (isDestructive ? terminalColors.danger : colors.onSurface);
    final bgColor = isSelected ? colors.onSurface : Colors.transparent;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: bgColor,
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.space * 2,
          vertical: AppSizes.space,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.bodyFamily,
                        color: textColor,
                        fontSize: AppSizes.fontStandard,
                        fontWeight: AppFonts.heavy,
                        package: 'pocketcoder_flutter',
                      ),
                    ),
                  ),
                  if (hasBadge) ...[
                    HSpace.x1,
                    Text(
                      '[!]',
                      style: TextStyle(
                        fontFamily: AppFonts.bodyFamily,
                        color: isSelected
                            ? colors.surface
                            : terminalColors.warning,
                        fontSize: AppSizes.fontStandard,
                        fontWeight: AppFonts.heavy,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              HSpace.x2,
              Flexible(
                child: Text(
                  value!.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: textColor,
                    fontSize: AppSizes.fontStandard,
                    fontWeight: AppFonts.heavy,
                    package: 'pocketcoder_flutter',
                  ),
                ),
              ),
            ] else
              Icon(
                Icons.chevron_right,
                size: 16,
                color: textColor.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }
}
