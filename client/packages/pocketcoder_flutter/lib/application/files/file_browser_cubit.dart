import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_state.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';
import 'package:pocketcoder_flutter/domain/models/file_tree_entry.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

@injectable
class FileBrowserCubit extends AppCubit<FileBrowserState> {
  final IFilesRepository _repository;

  /// The whole workspace tree, fetched once and navigated locally -- one
  /// network round trip covers every directory the user opens, instead of
  /// one per directory (the old listFiles-per-level behavior).
  List<FileTreeEntry>? _root;

  FileBrowserCubit(this._repository) : super(FileBrowserState.initial());

  /// Call with [refresh] true whenever the user lands on the files screen
  /// (not just when this cubit happens to be newly constructed) so files
  /// created after the tree was last fetched actually show up.
  Future<void> open(String path, {bool refresh = false}) async {
    logDebug('FileBrowserCubit: open(path: "$path", refresh: $refresh) -- '
        'cached root: ${_root != null}');
    return tryOperation(() async {
      if (refresh) _root = null;
      final root = _root ??= await _repository.listFileTree('');
      final entries = _entriesAt(root, path);
      logDebug('FileBrowserCubit: open(path: "$path") resolved '
          '${entries.length} entries out of ${root.length} root entries');
      return createSuccessState().copyWith(path: path, entries: entries);
    });
  }

  List<FileEntry> _entriesAt(List<FileTreeEntry> root, String path) {
    var level = root;
    if (path.isNotEmpty) {
      for (final segment in path.split('/')) {
        FileTreeEntry? match;
        for (final entry in level) {
          if (entry.isDir && entry.name == segment) {
            match = entry;
            break;
          }
        }
        if (match == null) return const [];
        level = match.children;
      }
    }
    return level
        .map((entry) => FileEntry(
              name: entry.name,
              isDir: entry.isDir,
              size: entry.size ?? 0,
              modTime: entry.modTime ?? '',
            ))
        .toList(growable: false);
  }

  Future<void> navigateInto(String name) async {
    final next = state.path.isEmpty ? name : '${state.path}/$name';
    await open(next);
  }

  Future<void> navigateUp() async {
    if (state.path.isEmpty) return;
    final segments = state.path.split('/')..removeLast();
    await open(segments.join('/'));
  }
}
