import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';

@LazySingleton(as: IFilesRepository)
class FilesRepository implements IFilesRepository {
  final PocketCoderApiClient _api;

  FilesRepository(this._api);

  @override
  Future<List<FileEntry>> listFiles(String path) async {
    return tryMethod(
      () async {
        final response = await _api.files.listWorkspaceFiles(path: path);
        final entries = response.data?.entries;
        if (entries == null) throw const FormatException('Missing file list');
        return entries
            .map((entry) => FileEntry(
                  name: entry.name,
                  isDir: entry.isDir,
                  size: entry.size,
                  modTime: entry.modTime,
                ))
            .toList(growable: false);
      },
      FilesException.new,
      'listFiles',
    );
  }

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
