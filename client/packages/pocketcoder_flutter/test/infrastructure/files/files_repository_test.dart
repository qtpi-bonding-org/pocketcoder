import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/infrastructure/files/files_repository.dart';

import '../../helpers/capturing_dio_adapter.dart';

void main() {
  late CapturingDioAdapter adapter;
  late FilesRepository repository;

  setUp(() {
    adapter = CapturingDioAdapter((options, _) {
      if (options.path.endsWith('/files-tree')) {
        return jsonResponse({
          'path': 'src',
          'entries': [
            {
              'name': 'main.go',
              'isDir': false,
              'size': 100,
              'modTime': '2026-07-25T10:00:00Z',
            },
            {
              'name': 'internal',
              'isDir': true,
              'children': [
                {
                  'name': 'nested.go',
                  'isDir': false,
                  'size': 42,
                  'modTime': '2026-07-25T10:00:00Z',
                },
              ],
            },
          ],
        });
      }
      return byteResponse([1, 2, 3]);
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://pb.local:8090'))
      ..httpClientAdapter = adapter;
    repository = FilesRepository(PocketCoderApiClient(dio: dio));
  });

  test('lists the full recursive file tree through the generated operation '
      'client, nesting children under their parent directory', () async {
    final result = await repository.listFileTree('src');

    expect(result, hasLength(2));
    expect(result[0].name, 'main.go');
    expect(result[0].isDir, isFalse);
    expect(result[0].children, isEmpty);
    expect(result[1].name, 'internal');
    expect(result[1].isDir, isTrue);
    expect(result[1].children, hasLength(1));
    expect(result[1].children.single.name, 'nested.go');
    expect(adapter.lastRequest?.path, '/api/pocketcoder/v1/files-tree');
    expect(adapter.lastRequest?.queryParameters, {'path': 'src'});
  });

  test('wraps generated client failures in FilesException for the tree call',
      () async {
    adapter.responder = (_, __) => jsonResponse(
          {'message': 'forbidden'},
          statusCode: 403,
        );

    await expectLater(
      () => repository.listFileTree('src'),
      throwsA(isA<FilesException>()),
    );
  });

  test('reads binary files through the generated operation client', () async {
    expect(await repository.readFile('main.go'), [1, 2, 3]);
    expect(adapter.lastRequest?.path, '/api/pocketcoder/v1/files');
    expect(adapter.lastRequest?.queryParameters, {'path': 'main.go'});
  });

  test('wraps generated client failures in FilesException for readFile',
      () async {
    adapter.responder = (_, __) => jsonResponse(
          {'message': 'forbidden'},
          statusCode: 403,
        );

    await expectLater(
      () => repository.readFile('main.go'),
      throwsA(isA<FilesException>()),
    );
  });
}
