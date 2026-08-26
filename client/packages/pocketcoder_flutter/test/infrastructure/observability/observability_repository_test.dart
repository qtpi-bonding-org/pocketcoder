import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/infrastructure/observability/observability_repository.dart';

import '../../helpers/capturing_dio_adapter.dart';

void main() {
  late CapturingDioAdapter adapter;
  late ObservabilityRepository repository;

  setUp(() {
    adapter = CapturingDioAdapter((options, _) => jsonResponse({
          'containers': [
            {'name': 'pocketcoder-app', 'state': 'running', 'status': 'Up 1h'},
            {'name': 'pocketcoder-worker', 'state': 'exited', 'status': 'Exited (1) 2h ago'},
          ],
        }));
    final dio = Dio(BaseOptions(baseUrl: 'http://pb.local:8090'))
      ..httpClientAdapter = adapter;
    repository = ObservabilityRepository(
      PocketBase('http://pb.local:8090'),
      PocketCoderApiClient(dio: dio),
    );
  });

  test('listContainers maps the generated response into ContainerInfo', () async {
    final result = await repository.listContainers();

    expect(result, hasLength(2));
    expect(result[0].name, 'pocketcoder-app');
    expect(result[0].state, 'running');
    expect(result[1].state, 'exited');
    expect(result[1].status, 'Exited (1) 2h ago');
  });

  test('listContainers wraps a transport failure in ObservabilityException', () async {
    adapter.responder = (_, __) => jsonResponse({'message': 'forbidden'}, statusCode: 500);

    await expectLater(
      () => repository.listContainers(),
      throwsA(isA<ObservabilityException>()),
    );
  });
}
