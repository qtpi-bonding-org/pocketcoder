import 'package:flutter/material.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:intl/intl.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';

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
    return BiosCard(
      header: [
        BiosRow(
          label: entry.errorData.source,
          value:
              '${entry.errorData.errorCode} · ${DateFormat.yMd().add_Hm().format(entry.lastOccurred)} · '
              '${context.l10n.errorsOccurred(entry.occurrenceCount)}',
          variant: BiosRowVariant.expand,
          isExpanded: _isExpanded,
          labelFontSize: AppSizes.fontSmall,
          onTap: () => setState(() => _isExpanded = !_isExpanded),
        ),
      ],
      body: _isExpanded
          ? Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSizes.space,
                    children: [
                      TerminalButton(
                        label: context.l10n.errorsReportOnGithub,
                        isPrimary: false,
                        onTap: () => widget.onReportOnGithub(entry.errorData),
                      ),
                      TerminalButton(
                        label: context.l10n.errorsCopy,
                        isPrimary: true,
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
            )
          : null,
      footer: BiosActionStrip(
        actions: [
          BiosActionStripItem(
            label: context.l10n.errorsDeleteAction,
            color: context.terminalColors.danger,
            onTap: () => widget.onDelete(entry.id),
          ),
        ],
      ),
    );
  }
}