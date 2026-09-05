import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/grid_wrap.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

// Re-export TerminalAction for backward compatibility
export 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart'
    show TerminalAction;

extension _TerminalActionExt on TerminalAction {
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
    final children = actions.map((action) {
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
      return Expanded(child: BiosActionButton(action: action._asStripItem));
    }).toList();

    return Container(
      width: double.infinity,
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: actions.length <= 4
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              )
            : GridWrap(
                spacing: 0,
                runSpacing: 0,
                alignment: WrapAlignment.end,
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
    );
  }
}
