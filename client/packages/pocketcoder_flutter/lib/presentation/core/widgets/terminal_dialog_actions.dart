import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';

class TerminalActionSpec {
  const TerminalActionSpec(this.label, this.kind, this.onTap);

  final String label;
  final ActionKind kind;
  final VoidCallback onTap;
}

class TerminalDialogActions extends StatelessWidget {
  const TerminalDialogActions({super.key, required this.actions});

  final List<TerminalActionSpec> actions;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSizes.space * 2,
        runSpacing: AppSizes.space,
        children: [
          for (final action in _ordered())
            TerminalButton(
              label: action.label,
              kind: action.kind,
              onTap: action.onTap,
            ),
        ],
      );

  /// Destructive actions never lead the row (spec section 7) -- swaps the
  /// first non-destructive action into first position rather than trusting
  /// every call site to order its own list correctly.
  List<TerminalActionSpec> _ordered() {
    if (actions.isEmpty || actions.first.kind.mayLeadRow) return actions;
    final rest = actions.sublist(1);
    final leaderIndex = rest.indexWhere((a) => a.kind.mayLeadRow);
    if (leaderIndex == -1) return actions;
    final reordered = [...rest];
    final leader = reordered.removeAt(leaderIndex);
    return [leader, actions.first, ...reordered];
  }
}
