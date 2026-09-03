import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class OnboardingContentShell extends StatelessWidget {
  const OnboardingContentShell({
    super.key,
    this.child,
    this.listBuilder,
    this.paddingMultiplier = 2,
    this.mainAxisAlignment = MainAxisAlignment.start,
  }) : assert((child == null) != (listBuilder == null));

  final Widget? child;
  final WidgetBuilder? listBuilder;
  final double paddingMultiplier;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final content = child == null
        ? listBuilder!(context)
        : SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              vertical: AppSizes.space * paddingMultiplier,
            ),
            child: mainAxisAlignment == MainAxisAlignment.start
                ? child
                : Column(
                    mainAxisAlignment: mainAxisAlignment,
                    children: [child!],
                  ),
          );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
        child: content,
      ),
    );
  }
}
