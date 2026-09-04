import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class DecisionFrame extends StatelessWidget {
  final Widget child;
  final String? title;

  const DecisionFrame({
    super.key,
    required this.child,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final borderColor = AppPalette.dim;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: AppSizes.contentMaxWidth,
          constraints: BoxConstraints(
              maxWidth: constraints.maxWidth - AppSizes.space * 4),
          child: Stack(
            children: [
              Container(
                key: const ValueKey('decision-frame-border'),
                margin: EdgeInsets.only(
                    top: AppSizes.space * 1.25), // Space for title
                padding: EdgeInsets.all(AppSizes.space * 2),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(
                      color: borderColor, width: AppSizes.borderWidthThick),
                ),
                child: child,
              ),
              if (title != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      color: colors.surface,
                      padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
                      child: TerminalText(title!, role: TextRole.label),
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
