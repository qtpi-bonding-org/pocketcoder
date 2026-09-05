import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

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
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: actions.map((action) {
              if (action.isLabel) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
                  child: Center(
                    child: TerminalText(
                      action.label,
                      role: TextRole.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }
              return BiosActionButton(action: action._asStripItem);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
