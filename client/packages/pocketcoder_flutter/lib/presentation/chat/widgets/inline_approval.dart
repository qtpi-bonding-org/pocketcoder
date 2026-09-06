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
    required this.toolLabel,
    required this.command,
    required this.requestId,
    required this.options,
    this.description,
    this.onSelect,
  });

  /// The tool's own name -- `shell`, `edit` -- not its ACP kind.
  final String toolLabel;
  final String command;
  final String requestId;
  final List<PermissionOption> options;
  final String? description;
  final void Function(String requestId, {String? optionId, bool cancelled})?
      onSelect;

  @override
  Widget build(BuildContext context) {
    // Hardcoded 'deny', not context.l10n.actionDeny: InlineApproval can be
    // mounted without AppLocalizations delegates configured, so a
    // context.l10n call here would throw.
    final actions = options.isEmpty
        ? [
            TerminalActionSpec(
              'deny',
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
        const TerminalText('poco wants to run:', role: TextRole.body),
        const SizedBox(height: 8),
        // `shell: python3 hello.py`. The label is dropped when it is absent,
        // or when it is all the harness gave us and would only repeat the
        // command back.
        TerminalText(
          toolLabel.isEmpty || toolLabel == command
              ? command
              : '$toolLabel: $command',
          role: TextRole.value,
        ),
        if (description != null && description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          TerminalText(
            description!,
            key: const ValueKey('inline-approval-description'),
            role: TextRole.body,
          ),
        ],
        const SizedBox(height: 12),
        // The request id never reaches the screen: it addresses the reply
        // this widget sends back, and means nothing to whoever is approving.
        TerminalDialogActions(actions: actions),
      ],
    );
  }
}
