import 'package:flutter/material.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:intl/intl.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';

class ErrorTile extends StatefulWidget {
  final ErrorBoxEntry entry;
  final Future<void> Function(ErrorEntry) onCopy;
  final Future<void> Function(ErrorEntry) onReportOnGithub;
  final Future<void> Function(String id) onDelete;

  const ErrorTile({
    super.key,
    required this.entry,
    required this.onCopy,
    required this.onReportOnGithub,
    required this.onDelete,
  });

  @override
  State<ErrorTile> createState() => _ErrorTileState();
}

class _ErrorTileState extends State<ErrorTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DetailRow(
        label: entry.errorData.source,
        value:
            '${entry.errorData.errorCode} · ${DateFormat.yMd().add_Hm().format(entry.lastOccurred)} · '
            '${context.l10n.errorsOccurred(entry.occurrenceCount)}',
        affordance: _isExpanded ? RowAffordance.collapse : RowAffordance.expand,
        onTap: () => setState(() => _isExpanded = !_isExpanded),
      ),
      if (_isExpanded) ...[
        VSpace.x1,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSizes.space,
            children: [
              TerminalButton(
                label: context.l10n.errorsReportOnGithub,
                kind: ActionKind.neutral,
                onTap: () => widget.onReportOnGithub(entry.errorData),
              ),
              TerminalButton(
                label: context.l10n.errorsCopy,
                kind: ActionKind.primary,
                onTap: () => widget.onCopy(entry.errorData),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(AppSizes.space),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(entry.errorData.stackTrace),
          ),
        ),
      ],
      VSpace.x1,
      BiosActionStrip(
        actions: [
          BiosActionStripItem(
            label: context.l10n.errorsDeleteAction,
            kind: ActionKind.destructive,
            onTap: () => widget.onDelete(entry.id),
          ),
        ],
      ),
      VSpace.x2,
    ]);
  }
}
