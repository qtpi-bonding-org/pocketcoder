// PermissionCard is the human-in-the-loop gatekeeper surface rendered inline
// in the message timeline. It is deliberately Cubit-free: the adapter owns
// permission side effects and supplies this view's callback.
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/inline_approval.dart';
import 'tool_command.dart';

class PermissionCard extends StatelessWidget {
  const PermissionCard({super.key, required this.item, required this.onSelect});

  final PermissionRequestTimelineItem item;
  final void Function(String requestId, {String? optionId, bool cancelled})
      onSelect;

  @override
  Widget build(BuildContext context) {
    final requestId = item.requestId;
    // Preserve the real formatted command produced from the protocol fields.
    // The fallback here is deliberately the generic placeholder, not
    // item.description: description renders as its own line below the
    // command, and using it as the command fallback too would show the
    // same text twice when there is no real command.
    final command = commandFor(
      name: item.toolTitle ?? '',
      args: item.toolArgs ?? '',
      toolKind: item.toolKind,
      fallback: context.l10n.permissionRequestedFallback,
    );

    return InlineApproval(
      toolKindLabel: item.toolKind ?? '',
      command: command,
      requestId: requestId,
      options: item.options,
      description: item.description,
      onSelect: onSelect,
    );
  }
}
