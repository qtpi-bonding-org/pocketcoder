import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class CountCard extends StatelessWidget {
  const CountCard({super.key, required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(AppSizes.space),
        decoration: BoxDecoration(
          border: Border.all(color: context.colorScheme.primary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: context.colorScheme.primary,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontLarge,
                fontWeight: AppFonts.heavy,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: context.colorScheme.onSurface,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
            ),
          ],
        ),
      );
}
