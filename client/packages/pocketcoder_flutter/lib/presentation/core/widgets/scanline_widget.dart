import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class ScanlineWidget extends StatelessWidget {
  final Widget child;

  const ScanlineWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Stack(
      children: [
        child,
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.onSurface.withValues(alpha: 0.0),
                  colors.onSurface.withValues(alpha: 0.02),
                  colors.onSurface.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
