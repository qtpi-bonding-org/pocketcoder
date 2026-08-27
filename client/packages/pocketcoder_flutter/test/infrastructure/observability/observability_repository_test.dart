import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';
import 'package:pocketcoder_flutter/infrastructure/observability/observability_repository.dart';

import '../../helpers/capturing_dio_adapter.dart';

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.body);

  final Stream<List<int>> body;
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    return http.StreamedResponse(body, 200, request: request);
  }
}

Stream<List<int>> _sseBody(String value) =>
    Stream<List<int>>.fromIterable([utf8.encode(value)]);

void main() {
  late CapturingDioAdapter adapter;
  late ObservabilityRepository repository;
  late _FakeHttpClient httpClient;

  setUp(() {
    adapter = CapturingDioAdapter((options, _) => jsonResponse({
          'containers': [
            {'name': 'pocketcoder-app', 'state': 'running', 'status': 'Up 1h'},
            {
              'name': 'pocketcoder-worker',
              'state': 'exited',
              'status': 'Exited (1) 2h ago'
            },
          ],
        }));
    final dio = Dio(BaseOptions(baseUrl: 'http://pb.local:8090'))
      ..httpClientAdapter = adapter;
    httpClient = _FakeHttpClient(_sseBody(''));
    repository = ObservabilityRepository(
      PocketBase('http://pb.local:8090'),
      PocketCoderApiClient(dio: dio),
      httpClient,
    );
  });

  test('listContainers maps the generated response into ContainerInfo',
      () async {
    final result = await repository.listContainers();

    expect(result, hasLength(2));
    expect(result[0].name, 'pocketcoder-app');
    expect(result[0].state, 'running');
    expect(result[1].state, 'exited');
    expect(result[1].status, 'Exited (1) 2h ago');
  });

  test('listContainers wraps a transport failure in ObservabilityException',
      () async {
    adapter.responder =
        (_, __) => jsonResponse({'message': 'forbidden'}, statusCode: 500);

    await expectLater(
      () => repository.listContainers(),
      throwsA(isA<ObservabilityException>()),
    );
  });

  test('watchLogs emits decoded SSE data and closes when the body closes',
      () async {
    httpClient = _FakeHttpClient(
        _sseBody('data: 2024-01-01T00:00:00.000000000Z log line\n\n'));
    repository = _repository(httpClient);

    final stream = repository.watchLogs('worker');
    await expectLater(
        stream,
        emitsInOrder([
          isA<LogEntry>().having((e) => e.message, 'message', 'log line'),
          emitsDone,
        ]));

    expect(httpClient.lastRequest?.url.toString(),
        'http://pb.local:8090${StreamingEndpoints.logs('worker')}');
    expect(httpClient.lastRequest?.headers['accept'], 'text/event-stream');
    expect(httpClient.lastRequest?.headers['cache-control'], 'no-cache');
  });

  test('watchLogs sends Authorization when authenticated', () async {
    final pb = PocketBase('http://pb.local:8090');
    pb.authStore.save('test-token', null);
    httpClient = _FakeHttpClient(
        _sseBody('data: 2024-01-01T00:00:00.000000000Z ok\n\n'));
    repository = _repository(httpClient, pb: pb);

    await expectLater(
        repository.watchLogs('app'),
        emitsInOrder([
          isA<LogEntry>().having((e) => e.message, 'message', 'ok'),
          emitsDone,
        ]));

    expect(httpClient.lastRequest?.headers['authorization'], 'test-token');
  });

  test('watchLogs omits Authorization when signed out', () async {
    httpClient = _FakeHttpClient(
        _sseBody('data: 2024-01-01T00:00:00.000000000Z ok\n\n'));
    repository = _repository(httpClient);

    await expectLater(
        repository.watchLogs('app'),
        emitsInOrder([
          isA<LogEntry>().having((e) => e.message, 'message', 'ok'),
          emitsDone,
        ]));

    expect(
        httpClient.lastRequest?.headers.containsKey('authorization'), isFalse);
  });

  test('cancelling watchLogs cancels the underlying SSE body', () async {
    var cancelled = false;
    final body = StreamController<List<int>>();
    body.onCancel = () {
      cancelled = true;
    };
    httpClient = _FakeHttpClient(body.stream);
    repository = _repository(httpClient);

    final subscription = repository.watchLogs('app').listen((_) {});
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(cancelled, isTrue);
  });
}

ObservabilityRepository _repository(
  http.Client client, {
  PocketBase? pb,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://pb.local:8090'));
  return ObservabilityRepository(
    pb ?? PocketBase('http://pb.local:8090'),
    PocketCoderApiClient(dio: dio),
    client,
  );
}
