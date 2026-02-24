import 'package:flutter/material.dart';
import '../../../design_system/theme/app_theme.dart';
import 'bios_frame.dart';

class TerminalDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const TerminalDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(AppSizes.space * 2),
      child: BiosFrame(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            content,
            VSpace.x2,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

class TerminalButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? color;

  const TerminalButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isPrimary = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final accentColor =
        color ?? (isPrimary ? colors.primary : colors.onSurface);
    final textColor = colors.surface; // True Black
    final bgColor = accentColor;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.space * 2,
          vertical: AppSizes.space,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: accentColor, width: AppSizes.borderWidth),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: textColor,
            fontSize: AppSizes.fontTiny,
            fontWeight: AppFonts.heavy,
          ),
        ),
      ),
    );
  }
}
