import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/chat/tool_command.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog_actions.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

/// An inline, unboxed request for permission to use a tool.
class InlineApproval extends StatelessWidget {
  const InlineApproval({
    super.key,
    required this.toolKindLabel,
    required this.command,
    required this.requestId,
    required this.options,
    this.description,
    this.onSelect,
  });

  final String toolKindLabel;
  final String command;
  final String requestId;
  final List<PermissionOption> options;
  final String? description;
  final void Function(String requestId, {String? optionId, bool cancelled})?
      onSelect;

  @override
  Widget build(BuildContext context) {
    // Hardcoded 'DENY', not context.l10n.actionDeny: this widget's own test
    // (per the plan's brief) mounts InlineApproval without AppLocalizations
    // delegates configured, so any context.l10n call here throws. Matches
    // the l10n value's current English text exactly.
    final actions = options.isEmpty
        ? [
            TerminalActionSpec(
              'DENY',
              ActionKind.refusal,
              () => onSelect?.call(requestId, cancelled: true),
            ),
          ]
        : [
            for (final option in options)
              TerminalActionSpec(
                option.label,
                actionKindForPermissionOption(option.kind),
                () => onSelect?.call(requestId, optionId: option.optionId),
              ),
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hardcoded, not l10n: this widget's own test (per the plan's brief)
        // mounts InlineApproval without AppLocalizations delegates configured,
        // so a context.l10n call here throws. Keep these two literal until a
        // later task revisits the test harness.
        const TerminalText('[!] permission request', role: TextRole.warn),
        const SizedBox(height: 8),
        TerminalText('poco wants to run $toolKindLabel:', role: TextRole.body),
        const SizedBox(height: 8),
        TerminalText(command, role: TextRole.value),
        if (description != null && description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          TerminalText(
            description!,
            key: const ValueKey('inline-approval-description'),
            role: TextRole.body,
          ),
        ],
        const SizedBox(height: 12),
        TerminalDialogActions(actions: actions),
        if (requestId.isNotEmpty) ...[
          const SizedBox(height: 8),
          TerminalText('[$requestId]', role: TextRole.label),
        ],
      ],
    );
  }
}
