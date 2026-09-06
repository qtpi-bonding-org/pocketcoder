import 'package:flutter/material.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
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

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final timeDate = DateTime(time.year, time.month, time.day);

    if (timeDate == today) {
      // Today: HH:mm
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      // Older: MM-DD HH:mm
      return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final timestamp = _formatTimestamp(entry.lastOccurred);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DetailRow(
        label: timestamp,
        value: '${entry.errorData.source}  ${entry.occurrenceCount}x',
        affordance: _isExpanded ? RowAffordance.collapse : RowAffordance.expand,
        onTap: () => setState(() => _isExpanded = !_isExpanded),
      ),
      // Error code on its own line, indented
      Padding(
        padding: EdgeInsets.only(left: AppSizes.ch * 4, top: AppSizes.space * 0.5),
        child: TerminalText(
          entry.errorData.errorCode,
          role: TextRole.fail,
        ),
      ),
      if (_isExpanded) ...[
        VSpace.x1,
        // Stack trace
        Padding(
          padding: EdgeInsets.only(left: AppSizes.ch * 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(entry.errorData.stackTrace),
          ),
        ),
        VSpace.x1,
        // Buttons in expanded section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.ch * 2),
          child: Wrap(
            spacing: AppSizes.space,
            runSpacing: AppSizes.space,
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
              TerminalButton(
                label: context.l10n.errorsDeleteAction,
                kind: ActionKind.destructive,
                onTap: () => widget.onDelete(entry.id),
              ),
            ],
          ),
        ),
      ],
      VSpace.x2,
    ]);
  }
}
