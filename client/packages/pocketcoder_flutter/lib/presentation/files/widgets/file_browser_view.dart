import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';

class FileBrowserView extends StatelessWidget {
  final void Function(BuildContext context, String path) onOpenFile;
  final ValueChanged<String> onNavigateInto;
  final FileBrowserState state;

  const FileBrowserView(
      {super.key,
      required this.onOpenFile,
      required this.onNavigateInto,
      required this.state});

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
        footer: buildPillarFooter(context, NavPillar.chat),
        showBack: true,
        body: Builder(builder: (context) {
          if (state.isLoading) {
            return const Center(child: TerminalLoadingIndicator());
          }
          if (state.entries.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(AppSizes.space * 4),
                child:
                    TerminalText(context.l10n.filesEmpty, role: TextRole.label),
              ),
            );
          }
          return ListView(children: [
            Padding(
              padding: EdgeInsets.all(AppSizes.space),
              child: TerminalText('/${state.path}', role: TextRole.label),
            ),
            ...state.entries.map((entry) => _entryRow(context, state, entry)),
          ]);
        }));
  }

  Widget _entryRow(
      BuildContext context, FileBrowserState state, FileEntry entry) {
    return DetailRow(
        label: entry.name,
        value: entry.isDir ? '[DIR]' : '[FILE]',
        affordance: RowAffordance.navigate,
        onTap: () {
          if (entry.isDir) {
            onNavigateInto(entry.name);
          } else {
            final fullPath =
                state.path.isEmpty ? entry.name : '${state.path}/${entry.name}';
            onOpenFile(context, fullPath);
          }
        });
  }
}
