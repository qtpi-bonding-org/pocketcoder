import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'terminal_text.dart';

class TintedAlertCard extends StatelessWidget {
  const TintedAlertCard({
    super.key,
    required this.eyebrowLeft,
    required this.eyebrowRight,
    required this.tint,
    required this.child});

  final String eyebrowLeft;
  final String eyebrowRight;
  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space * 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.05),
        border: Border.all(
          color: tint.withValues(alpha: 0.3),
          width: AppSizes.borderWidth)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TerminalText(
                eyebrowLeft,
                role: TextRole.value,
              ),
              HSpace.x1,
              Expanded(
                child: TerminalText(
                  eyebrowRight,
                  role: TextRole.value,
                )),
            ]),
          VSpace.x2,
          child,
        ]));
  }
}
