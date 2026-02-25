import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class BiosFrame extends StatelessWidget {
  final Widget child;
  final String? title;

  const BiosFrame({
    super.key,
    required this.child,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    final borderColor = colors.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: 500,
          constraints: BoxConstraints(
              maxWidth: constraints.maxWidth - AppSizes.space * 4),
          child: Stack(
            children: [
              // Main Box
              Container(
                margin: EdgeInsets.only(
                    top: AppSizes.space * 1.25), // Space for title
                padding: EdgeInsets.all(AppSizes.space * 2),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(
                      color: borderColor, width: AppSizes.borderWidthThick),
                  boxShadow: [
                    BoxShadow(
                      color: terminalColors.glow,
                      blurRadius: AppSizes.radiusSmall + 2,
                      spreadRadius: AppSizes.borderWidthThick,
                    ),
                  ],
                ),
                child: child,
              ),
              // Title Overlay
              if (title != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      color: colors.surface,
                      padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
                      child: Text(
                        '[ $title ]',
                        style: TextStyle(
                          fontFamily: AppFonts.bodyFamily,
                          package: 'pocketcoder_flutter',
                          color: borderColor,
                          fontWeight: AppFonts.heavy,
                          backgroundColor: colors.surface,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
