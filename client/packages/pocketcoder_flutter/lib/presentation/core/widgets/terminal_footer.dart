import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

// Re-export TerminalAction for backward compatibility
export 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart'
    show TerminalAction;

extension _TerminalActionExt on TerminalAction {
  BiosActionStripItem asStripItem({bool bracketed = true}) =>
      BiosActionStripItem(
        label: label,
        onTap: onTap,
        hasBadge: hasBadge,
        isActive: isActive,
        kind: kind,
        bracketed: bracketed,
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
    // Unexpanded so a lone action left-aligns instead of centering in a
    // full-width Expanded slot.
    final soleAction = actions.length == 1 ? actions.single : null;
    final children = soleAction != null
        ? [
            if (soleAction.isLabel)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
                child: TerminalText(
                  soleAction.label,
                  role: TextRole.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              BiosActionButton(
                  action: soleAction.asStripItem(bracketed: false)),
          ]
        : actions.map((action) {
            if (action.isLabel) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
                  child: Center(
                    child: TerminalText(
                      action.label,
                      role: TextRole.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            }
            // The page footer is a persistent status bar, not a row of
            // discrete buttons: labels stay bare and reverse-video carries
            // the state.
            return Expanded(
                child: BiosActionButton(
                    action: action.asStripItem(bracketed: false)));
          }).toList();

    return Container(
      width: double.infinity,
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: IntrinsicHeight(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.screenInset),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
