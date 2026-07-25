import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';

@LazySingleton(as: IFilesRepository)
class FilesRepository implements IFilesRepository {
  final PocketBase _pb;
  final http.Client _http;

  FilesRepository(this._pb, this._http);

  @override
  Future<List<FileEntry>> listFiles(String path) async {
    return tryMethod(
      () async {
        final response = await _pb.send<dynamic>(
          ApiEndpoints.filesList(path),
          method: 'GET',
        );
        final entries = (response as Map<String, dynamic>)['entries'] as List;
        return entries
            .map((e) => FileEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      FilesException.new,
      'listFiles',
    );
  }

  @override
  Future<List<int>> readFile(String path) async {
    return tryMethod(
      () async {
        final token = _pb.authStore.token;
        if (token.isEmpty) {
          throw FilesException.noAuthToken();
        }
        final uri = Uri.parse('${_pb.baseURL}${ApiEndpoints.files(path)}');
        final response = await _http.get(uri, headers: {'Authorization': token});
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw FilesException.httpError(response.statusCode);
        }
        return response.bodyBytes;
      },
      FilesException.new,
      'readFile',
    );
  }
}
