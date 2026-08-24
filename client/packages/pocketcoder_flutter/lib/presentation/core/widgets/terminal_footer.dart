import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';

/// A configuration object for a single footer button
class TerminalAction {
  final String label; // e.g. "HELP"
  final VoidCallback onTap;
  final bool hasBadge;
  final bool isActive;
  final Color? color;

  /// Overrides the emphasis derived from [isActive] -- lets a footer
  /// button read as the recommended next action (.outlined) without being
  /// the active tab. See the emphasis-states spec (2026-08-23).
  final Emphasis? emphasis;

  TerminalAction({
    required this.label,
    required this.onTap,
    this.hasBadge = false,
    this.isActive = false,
    this.color,
    this.emphasis,
  });

  BiosActionStripItem get _asStripItem => BiosActionStripItem(
        label: label,
        onTap: onTap,
        hasBadge: hasBadge,
        isActive: isActive,
        color: color,
        emphasis: emphasis,
      );
}

class TerminalFooter extends StatelessWidget {
  final List<TerminalAction> actions;

  const TerminalFooter({
    super.key,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    // A single green line to separate footer from content
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.onSurface, width: AppSizes.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: actions.map((action) {
                final stripItem = action._asStripItem;
                final showDivider =
                    stripItem.resolvedEmphasis != Emphasis.outlined;
                return Container(
                  decoration: BoxDecoration(
                    border: showDivider
                        ? Border(
                            right: BorderSide(
                              color: colors.onSurface.withValues(alpha: 0.1),
                              width: AppSizes.borderWidth,
                            ),
                          )
                        : null,
                  ),
                  child: BiosActionButton(action: stripItem),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
