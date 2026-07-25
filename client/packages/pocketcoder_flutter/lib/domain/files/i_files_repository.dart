import 'package:pocketcoder_flutter/domain/models/file_entry.dart';

abstract class IFilesRepository {
  Future<List<FileEntry>> listFiles(String path);
  Future<List<int>> readFile(String path);
}
