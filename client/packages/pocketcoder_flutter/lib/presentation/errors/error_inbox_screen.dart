// lib/presentation/errors/error_inbox_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:intl/intl.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class ErrorInboxScreen extends StatelessWidget {
  const ErrorInboxScreen({
    super.key,
    required this.errors,
    required this.onCopyAll,
    required this.onClearAll,
    required this.onCopy,
    required this.onDelete,
  });

  final List<ErrorBoxEntry> errors;
  final VoidCallback onCopyAll;
  final VoidCallback onClearAll;
  final Future<void> Function(ErrorEntry) onCopy;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
        title: context.l10n.errorsTitle,
        activePillar: NavPillar.configure,
        showBack: true,
        body: BiosFrame(
          title: context.l10n.errorsTitle,
          child: Builder(builder: (context) {
              if (errors.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(AppSizes.space * 2),
                  child: TerminalText(
                    context.l10n.errorsEmpty,
                    size: TerminalTextSize.small,
                  ),
                );
              }
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(AppSizes.space),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSizes.space,
                      children: [
                        TerminalButton(
                          label: context.l10n.errorsCopyAll,
                          isPrimary: true,
                          onTap: onCopyAll,
                        ),
                        TerminalButton(
                          label: context.l10n.errorsClearAll,
                          isPrimary: false,
                          onTap: onClearAll,
                        ),
                      ],
                    ),
                  ),
                  for (final entry in errors)
                    _ErrorTile(entry: entry, onCopy: onCopy, onDelete: onDelete),
                ],
              );
            }),
        ),
      );
  }
}

class _ErrorTile extends StatelessWidget {
  final ErrorBoxEntry entry;
  final Future<void> Function(ErrorEntry) onCopy;
  final Future<void> Function(String id) onDelete;

  const _ErrorTile({
    required this.entry,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // ExpansionTile's internal ListTile paints ink/background on the
    // nearest Material ancestor. BiosFrame/BiosSection wrap this tile in a
    // colored DecoratedBox, not a Material, which makes ListTile's splash
    // invisible and trips a framework assertion — wrap in a transparent
    // Material to give it a proper painting surface without altering the
    // BIOS-style chrome behind it.
    return Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
        title:
            TerminalText(entry.errorData.source, size: TerminalTextSize.small),
        subtitle: TerminalText(
          '${entry.errorData.errorCode} · ${DateFormat.yMd().add_Hm().format(entry.lastOccurred)} · '
          '${context.l10n.errorsOccurred(entry.occurrenceCount)}',
          size: TerminalTextSize.mini,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => onDelete(entry.id),
        ),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
            child: Align(
              alignment: Alignment.centerRight,
              child: TerminalButton(
                label: context.l10n.errorsCopy,
                isPrimary: true,
                onTap: () => onCopy(entry.errorData),
              ),
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
      ),
    );
  }
}
