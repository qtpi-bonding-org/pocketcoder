import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_cubit.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

/// Browses the shared workspace, one directory at a time.
///
/// [onOpenFile] is a callback rather than a direct `AppNavigation` call so
/// this widget stays testable without a real [GoRouter] — `app_router.dart`
/// wires the real navigation.
class FileBrowserScreen extends StatelessWidget {
  final void Function(BuildContext context, String path) onOpenFile;

  const FileBrowserScreen({super.key, required this.onOpenFile});

  @override
  Widget build(BuildContext context) {
    return UiFlowListener<FileBrowserCubit, FileBrowserState>(
      child: _FileBrowserView(onOpenFile: onOpenFile),
    );
  }
}

class _FileBrowserView extends StatelessWidget {
  final void Function(BuildContext context, String path) onOpenFile;

  const _FileBrowserView({required this.onOpenFile});

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.filesTitle,
      activePillar: NavPillar.chats,
      showBack: true,
      body: BlocBuilder<FileBrowserCubit, FileBrowserState>(
        builder: (context, state) {
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
        },
      ),
    );
  }

  Widget _entryRow(BuildContext context, FileBrowserState state, FileEntry entry) {
    return ListTile(
      leading: Icon(entry.isDir ? Icons.folder : Icons.insert_drive_file),
      title: TerminalText(entry.name),
      onTap: () {
        if (entry.isDir) {
          context.read<FileBrowserCubit>().navigateInto(entry.name);
        } else {
          final fullPath = state.path.isEmpty ? entry.name : '${state.path}/${entry.name}';
          onOpenFile(context, fullPath);
        }
      },
    );
  }
}
