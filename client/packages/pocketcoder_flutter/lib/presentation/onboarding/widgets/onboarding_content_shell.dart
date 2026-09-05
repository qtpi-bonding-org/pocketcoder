import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';

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
    // listBuilder hands back a self-scrolling ListView: clamp its width
    // only, same as a `scrollable: false` PocketCoderShell body would.
    if (listBuilder != null) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
          child: listBuilder!(context),
        ),
      );
    }
    return ContentScrollRegion(
      padding: EdgeInsets.symmetric(
        vertical: AppSizes.space * paddingMultiplier,
      ),
      child: mainAxisAlignment == MainAxisAlignment.start
          ? child!
          : Column(
              mainAxisAlignment: mainAxisAlignment,
              children: [child!],
            ),
    );
  }
}
