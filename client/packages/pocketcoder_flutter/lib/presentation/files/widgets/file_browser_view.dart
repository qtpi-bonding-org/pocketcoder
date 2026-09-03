import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class FileBrowserView extends StatelessWidget {
  final void Function(BuildContext context, String path) onOpenFile;
  final ValueChanged<String> onNavigateInto;
  final FileBrowserState state;

  const FileBrowserView({
    super.key,
    required this.onOpenFile,
    required this.onNavigateInto,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.filesTitle,
      activePillar: NavPillar.chats,
      showBack: true,
      body: Builder(builder: (context) {
          if (state.isLoading) {
            return const Center(child: TerminalLoadingIndicator());
          }
          if (state.entries.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(AppSizes.space * 4),
                child: TerminalText(context.l10n.filesEmpty, alpha: 0.5),
              ),
            );
          }
          return ListView(
            children: [
              Padding(
                padding: EdgeInsets.all(AppSizes.space),
                child: TerminalText.mini('/${state.path}', alpha: 0.6),
              ),
              ...state.entries.map((entry) => _entryRow(context, state, entry)),
            ],
          );
        }),
    );
  }

  Widget _entryRow(BuildContext context, FileBrowserState state, FileEntry entry) {
    return ListTile(
      leading: TerminalText(entry.isDir ? '[DIR]' : '[FILE]'),
      title: TerminalText(entry.name),
      onTap: () {
        if (entry.isDir) {
          onNavigateInto(entry.name);
        } else {
          final fullPath = state.path.isEmpty ? entry.name : '${state.path}/${entry.name}';
          onOpenFile(context, fullPath);
        }
      },
    );
  }
}