import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class EmptyLabel extends StatelessWidget {
  const EmptyLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space),
        child: Text(
          label,
          style: TextStyle(
            color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontSmall,
          ),
        ),
      );
}
