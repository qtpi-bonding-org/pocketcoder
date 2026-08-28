import 'package:pocketcoder_flutter/domain/models/file_tree_entry.dart';

abstract class IFilesRepository {
  /// The full recursive tree under [path] in one call, for building a
  /// navigable file tree without a round trip per directory expansion.
  Future<List<FileTreeEntry>> listFileTree(String path);
  Future<List<int>> readFile(String path);
}
