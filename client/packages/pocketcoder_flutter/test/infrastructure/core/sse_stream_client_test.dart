import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketcoder_flutter/infrastructure/core/sse_stream_client.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient({required this.body, this.statusCode = 200});

  final Stream<List<int>> body;
  final int statusCode;
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    return http.StreamedResponse(body, statusCode, request: request);
  }
}

Stream<List<int>> _body(String text) =>
    Stream<List<int>>.fromIterable([utf8.encode(text)]);

void main() {
  test('decodes a single-line data record', () async {
    final client =
        SseStreamClient(httpClient: _FakeClient(body: _body('data: foo\n\n')));

    final frames = await client
        .connect(() => http.Request('GET', Uri.http('example.test', '/')))
        .toList();

    expect(frames, hasLength(1));
    expect(frames.single.data, 'foo');
  });

  test('joins consecutive data lines with a newline', () async {
    final client = SseStreamClient(
      httpClient: _FakeClient(
          body: _body('data: first\ndata: second\ndata: third\n\n')),
    );

    final frames = await client
        .connect(() => http.Request('GET', Uri.http('example.test', '/')))
        .toList();

    expect(frames.single.data, 'first\nsecond\nthird');
  });

  test('captures event and raw id, and defaults event to null', () async {
    final client = SseStreamClient(
      httpClient: _FakeClient(
        body:
            _body('id: cursor-007\nevent: message\ndata: one\n\ndata: two\n\n'),
      ),
    );

    final frames = await client
        .connect(() => http.Request('GET', Uri.http('example.test', '/')))
        .toList();

    expect(frames[0], (id: 'cursor-007', event: 'message', data: 'one'));
    expect(frames[1], (id: null, event: null, data: 'two'));
  });

  test('comments and comment-only records produce no frames', () async {
    final client = SseStreamClient(
      httpClient: _FakeClient(body: _body(': heartbeat\n\n: another\n')),
    );

    expect(
      await client
          .connect(() => http.Request('GET', Uri.http('example.test', '/')))
          .toList(),
      isEmpty,
    );
  });

  test('non-2xx response throws without parsing body', () async {
    final client = SseStreamClient(
      httpClient: _FakeClient(
          body: _body('data: should not parse\n\n'), statusCode: 503),
    );

    expect(
      () => client
          .connect(() => http.Request('GET', Uri.http('example.test', '/')))
          .toList(),
      throwsA(isA<SseHttpException>()
          .having((e) => e.statusCode, 'statusCode', 503)),
    );
  });

  test('completes when response body closes', () async {
    final client =
        SseStreamClient(httpClient: _FakeClient(body: _body('data: done\n\n')));

    final frames = await client
        .connect(() => http.Request('GET', Uri.http('example.test', '/')))
        .toList();

    expect(frames.single.data, 'done');
  });

  test('cancelling before send completes aborts the response body', () async {
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () => cancelled = true);
    final client = SseStreamClient(httpClient: _FakeClient(body: body.stream));

    final subscription = client
        .connect(() => http.Request('GET', Uri.http('example.test', '/')))
        .listen((_) {});
    await subscription.cancel();
    await Future<void>.delayed(Duration.zero);

    expect(cancelled, isTrue);
    await body.close();
  });

  test('cancel aborts all in-flight connections', () async {
    var cancellations = 0;
    StreamController<List<int>> makeBody() => StreamController<List<int>>(
          onCancel: () => cancellations++,
        );
    final body1 = makeBody();
    final body2 = makeBody();
    final client = SseStreamClient(
      httpClient: _QueueClient([body1.stream, body2.stream]),
    );

    final first = client
        .connect(() => http.Request('GET', Uri.http('example.test', '/')))
        .listen((_) {});
    final second = client
        .connect(() => http.Request('GET', Uri.http('example.test', '/')))
        .listen((_) {});
    await Future<void>.delayed(Duration.zero);
    await client.cancel();

    expect(cancellations, 2);
    await first.cancel();
    await second.cancel();
    await body1.close();
    await body2.close();
  });
}

class _QueueClient extends http.BaseClient {
  _QueueClient(this.bodies);
  final List<Stream<List<int>>> bodies;
  var index = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(bodies[index++], 200, request: request);
}
