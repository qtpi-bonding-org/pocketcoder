import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';

/// A configuration object for a single footer button
class TerminalAction {
  final String label; // e.g. "help"
  final VoidCallback onTap;
  final bool hasBadge;
  final bool isActive;
  final ActionKind kind;
  final bool isLabel;

  TerminalAction({
    required this.label,
    required this.onTap,
    this.hasBadge = false,
    this.isActive = false,
    this.kind = ActionKind.neutral,
    this.isLabel = false,
  });

  BiosActionStripItem get _asStripItem => BiosActionStripItem(
        label: label,
        onTap: onTap,
        hasBadge: hasBadge,
        isActive: isActive,
        kind: kind,
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
                final showDivider = stripItem.kind != ActionKind.primary;
                if (action.isLabel)
                  return Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: AppSizes.space * 2),
                    child: Center(child: Text(action.label)),
                  );
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
