import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/decision_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/errors/widgets/error_tile.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';

class ErrorInboxScreen extends StatelessWidget {
  const ErrorInboxScreen(
      {super.key,
      required this.errors,
      required this.onCopyAll,
      required this.onClearAll,
      required this.onCopy,
      required this.onReportOnGithub,
      required this.onDelete});

  final List<ErrorBoxEntry> errors;
  final VoidCallback onCopyAll;
  final VoidCallback onClearAll;
  final Future<void> Function(ErrorEntry) onCopy;
  final Future<void> Function(ErrorEntry) onReportOnGithub;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
        title: context.l10n.errorsTitle.toLowerCase(),
        activePillar: NavPillar.configure,
        showBack: true,
        body: DecisionFrame(
            title: context.l10n.errorsTitle.toLowerCase(),
            child: Builder(builder: (context) {
              if (errors.isEmpty) {
                return Padding(
                    padding: EdgeInsets.all(AppSizes.space * 2),
                    child: TerminalText(
                      context.l10n.errorsEmpty,
                      role: TextRole.body,
                    ));
              }
              return Column(children: [
                Padding(
                    padding: EdgeInsets.all(AppSizes.space),
                    child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: AppSizes.space,
                        children: [
                          BiosActionButton(
                              action: BiosActionStripItem(
                                  label: context.l10n.errorsCopyAll,
                                  kind: ActionKind.primary,
                                  onTap: onCopyAll)),
                          BiosActionButton(
                              action: BiosActionStripItem(
                                  label: context.l10n.errorsClearAll,
                                  kind: ActionKind.destructive,
                                  onTap: onClearAll)),
                        ])),
                // A plain Column here overflows once the tiles' combined
                // height (an expanded tile's full stack trace especially)
                // exceeds the frame's bounded height -- this list needs to
                // scroll on its own rather than push past the frame.
                Expanded(
                    child: ListView(children: [
                  for (final entry in errors)
                    ErrorTile(
                        entry: entry,
                        onCopy: onCopy,
                        onReportOnGithub: onReportOnGithub,
                        onDelete: onDelete),
                ])),
              ]);
            })));
  }
}
