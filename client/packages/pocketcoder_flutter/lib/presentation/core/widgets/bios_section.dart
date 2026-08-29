import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class BiosSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool centerTitle;

  const BiosSection({
    super.key,
    required this.title,
    required this.child,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final titleText = Text(
      title.toUpperCase(),
      style: TextStyle(
        fontFamily: AppFonts.bodyFamily,
        color: colors.primary,
        fontWeight: AppFonts.heavy,
        fontSize: AppSizes.fontTiny,
        letterSpacing: 1.2,
        package: 'pocketcoder_flutter',
      ),
    );
    Widget divider() => Divider(
          color: colors.primary.withValues(alpha: 0.3),
          thickness: AppSizes.borderWidth,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: centerTitle
              ? [
                  Expanded(child: divider()),
                  HSpace.x1,
                  titleText,
                  HSpace.x1,
                  Expanded(child: divider()),
                ]
              : [
                  titleText,
                  HSpace.x1,
                  Expanded(child: divider()),
                ],
        ),
        VSpace.x1,
        child,
        VSpace.x2,
      ],
    );
  }
}
