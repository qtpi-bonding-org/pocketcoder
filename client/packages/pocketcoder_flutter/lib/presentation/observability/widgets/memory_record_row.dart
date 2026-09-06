import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class MemoryRecordRow extends StatelessWidget {
  const MemoryRecordRow(
      {super.key,
      required this.author,
      required this.createdAt,
      required this.body,
      this.linkedObservations});

  final String author;
  final String createdAt;
  final String body;
  final List<String>? linkedObservations;

  @override
  Widget build(BuildContext context) {
    final linked = linkedObservations ?? const <String>[];
    return Padding(
        padding: EdgeInsets.only(bottom: AppSizes.space),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TerminalText(
            '$author · $createdAt',
            role: TextRole.label,
          ),
          TerminalText(
            body,
            role: TextRole.body,
          ),
          if (linked.isNotEmpty)
            TerminalText(
              context.l10n.memoryDashboardLinkedPrefix(linked.join(' | ')),
              role: TextRole.label,
            ),
        ]));
  }
}
