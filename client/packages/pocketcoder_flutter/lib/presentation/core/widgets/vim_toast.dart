import 'package:flutter/material.dart';
import '../../../design_system/theme/app_theme.dart';

class VimToast extends StatelessWidget {
  final String message;
  final Color? color;

  const VimToast({
    super.key,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final accentColor = color ?? colors.onSurface;

    // Calculate dashes based on message length (min 40)
    final int dashCount = (message.length + 4).clamp(40, 60);
    final String dashes = '-' * dashCount;

    return Container(
      padding: EdgeInsets.symmetric(vertical: AppSizes.space),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dashes,
            style: TextStyle(
              color: accentColor.withValues(alpha: 0.5),
              fontFamily: AppFonts.bodyFamily,
              package: 'pocketcoder_flutter',
              fontSize: 10,
              height: 0.5,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space * 0.5),
            child: Text(
              ' $message ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accentColor,
                fontFamily: AppFonts.bodyFamily,
                package: 'pocketcoder_flutter',
                fontSize: AppSizes.fontTiny,
                fontWeight: AppFonts.heavy,
              ),
            ),
          ),
          Text(
            dashes,
            style: TextStyle(
              color: accentColor.withValues(alpha: 0.5),
              fontFamily: AppFonts.bodyFamily,
              package: 'pocketcoder_flutter',
              fontSize: 10,
              height: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
