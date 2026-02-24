import 'package:flutter/material.dart';
import '../../../design_system/theme/app_theme.dart';

class BiosSection extends StatelessWidget {
  final String title;
  final Widget child;

  const BiosSection({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: colors.primary,
                fontWeight: AppFonts.heavy,
                fontSize: AppSizes.fontTiny,
                letterSpacing: 1.2,
                package: 'pocketcoder_flutter',
              ),
            ),
            HSpace.x1,
            Expanded(
              child: Divider(
                color: colors.primary.withValues(alpha: 0.3),
                thickness: AppSizes.borderWidth,
              ),
            ),
          ],
        ),
        VSpace.x1,
        child,
        VSpace.x2,
      ],
    );
  }
}
