import 'package:injectable/injectable.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart' as generated;
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/domain/models/file_tree_entry.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';

@LazySingleton(as: IFilesRepository)
class FilesRepository implements IFilesRepository {
  final PocketCoderApiClient _api;

  FilesRepository(this._api);

  @override
  Future<List<FileTreeEntry>> listFileTree(String path) async {
    return tryMethod(
      () async {
        final response = await _api.files.listWorkspaceFileTree(path: path);
        final entries = response.data?.entries;
        if (entries == null) throw const FormatException('Missing file tree');
        return entries.map(_convertTreeEntry).toList(growable: false);
      },
      FilesException.new,
      'listFileTree',
    );
  }

  FileTreeEntry _convertTreeEntry(generated.FileTreeEntry entry) => FileTreeEntry(
        name: entry.name,
        isDir: entry.isDir,
        size: entry.size,
        modTime: entry.modTime,
        children: entry.children?.map(_convertTreeEntry).toList(growable: false) ??
            const [],
      );

  @override
  Future<List<int>> readFile(String path) async {
    return tryMethod(
      () async {
        final response = await _api.files.getWorkspaceFile(path: path);
        final bytes = response.data;
        if (bytes == null) throw const FormatException('Missing file body');
        return bytes;
      },
      FilesException.new,
      'readFile',
    );
  }
}
