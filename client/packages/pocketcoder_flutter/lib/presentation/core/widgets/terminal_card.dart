import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

/// A reusable status-card container with optional active-state highlighting.
///
/// Replaces the repeated `Container` + `BoxDecoration` pattern used across
/// management screens (LLM, MCP, tool-permissions, billing).
class TerminalCard extends StatelessWidget {
  final Widget child;
  final bool isActive;
  final VoidCallback? onTap;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  const TerminalCard({
    super.key,
    required this.child,
    this.isActive = false,
    this.onTap,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    final container = Container(
      margin: margin ?? EdgeInsets.only(bottom: AppSizes.space),
      padding: padding ?? EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        border: Border.all(
          color: isActive
              ? colors.primary.withValues(alpha: 0.5)
              : colors.onSurface.withValues(alpha: 0.2),
        ),
        color: isActive ? colors.primary.withValues(alpha: 0.05) : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }
}
