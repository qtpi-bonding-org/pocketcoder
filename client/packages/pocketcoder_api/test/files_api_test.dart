import 'package:test/test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart';


/// tests for FilesApi
void main() {
  final instance = PocketcoderApi().getFilesApi();

  group(FilesApi, () {
    //Future<Uint8List> getWorkspaceFile(String path) async
    test('test getWorkspaceFile', () async {
      // TODO
    });

    //Future<FileTreeResponse> listWorkspaceFileTree({ String path }) async
    test('test listWorkspaceFileTree', () async {
      // TODO
    });

  });
}
