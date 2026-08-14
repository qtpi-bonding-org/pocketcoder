// Tests for AgentStreamClient (plan Task 8). These tests construct a fake
// `http.Client` whose `.send` returns an `http.StreamedResponse` backed by a
// synthetic byte stream — no real network, no `mocktail`. We use
// `http.MockClient` (hand-rolled here) because the only framework-level
// fake is `package:http.MockClient`, and even that requires a body-builder
// callback. We extend it minimally to capture the request and serve a
// caller-supplied byte stream.
import 'dart:async';
import 'dart:convert';

import 'package:ag_ui/ag_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_stream_client.dart';

/// Records the most recent request handed to `.send` and returns a
/// `StreamedResponse` built from [bytes] (a single-subscription
/// `Stream<List<int>>`). Implements just enough of `http.Client` to be
/// usable here — the only method AgentStreamClient calls is `.send`.
class _FakeClient extends http.BaseClient {
  /// What the fake `PocketBase.authStore.token` will be set to.
  static const fakeToken = 'pb-test-token-abc123';

  /// The single request observed; asserted in tests.
  http.BaseRequest? lastRequest;

  /// The byte stream the test wants the fake to serve. Default: empty.
  final Stream<List<int>> body;
  final int statusCode;

  _FakeClient({required this.body, this.statusCode = 200});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    return http.StreamedResponse(
      body,
      statusCode,
      contentLength: null,
      request: request,
      headers: const {'Content-Type': 'text/event-stream'},
    );
  }
}

/// Build a `PocketBase` whose only meaningful fields are `baseURL` and
/// `authStore.token`. We never call any PocketBase network API in these
/// tests — `AgentStreamClient` only reads those two fields off the
/// injected instance. We construct it without registering any global
/// services to keep the test hermetic.
PocketBase _fakePb({String baseUrl = 'http://pb.local'}) {
  final pb = PocketBase(baseUrl);
  pb.authStore.save(_FakeClient.fakeToken, null);
  return pb;
}

void main() {
  // The single RUN_STARTED JSON the tests build frames around.
  final runStartedJson = jsonEncode({
    'type': 'RUN_STARTED',
    'threadId': 't',
    'runId': 'r',
  });
  final textContentJson = jsonEncode({
    'type': 'TEXT_MESSAGE_CONTENT',
    'messageId': 'm1',
    'delta': 'hello',
  });
  final runFinishedJson = jsonEncode({
    'type': 'RUN_FINISHED',
    'threadId': 't',
    'runId': 'r',
  });

  group('connect()', () {
    test(
      'parses a single SSE frame into a StreamFrame with the right seq + '
      'decoded event',
      () async {
        final body = Stream<List<int>>.fromIterable([
          utf8.encode('id: 3\ndata: $runStartedJson\n\n'),
        ]);
        final fake = _FakeClient(body: body);
        final client = AgentStreamClient(
          pocketBase: _fakePb(),
          httpClient: fake,
        );

        final frames = await client.connect('chat-1', cursor: 0).toList();

        expect(frames, hasLength(1));
        expect(frames.single.seq, 3);
        expect(frames.single.rawJson, runStartedJson);
        expect(frames.single.event, isA<RunStartedEvent>());
        final ev = frames.single.event as RunStartedEvent;
        expect(ev.threadId, 't');
        expect(ev.runId, 'r');
      },
    );

    test('parses multiple frames in one streamed body in order', () async {
      // Three frames: seq 1, seq 2, seq 3 — interleaved with a comment to
      // also exercise the comment-skipping branch.
      final body = Stream<List<int>>.fromIterable([
        utf8.encode(
          'id: 1\n'
          'data: $runStartedJson\n'
          '\n'
          ': ping\n' // comment must not produce a frame
          'id: 2\n'
          'data: $textContentJson\n'
          '\n'
          'id: 3\n'
          'data: $runFinishedJson\n'
          '\n',
        ),
      ]);
      final fake = _FakeClient(body: body);
      final client = AgentStreamClient(
        pocketBase: _fakePb(),
        httpClient: fake,
      );

      final frames = await client.connect('chat-1', cursor: 0).toList();

      expect(frames, hasLength(3));
      expect(frames.map((f) => f.seq), [1, 2, 3]);
      expect(frames[0].event, isA<RunStartedEvent>());
      expect(frames[1].event, isA<TextMessageContentEvent>());
      expect(frames[2].event, isA<RunFinishedEvent>());
      // rawJson must be the verbatim `data:` JSON (no re-encode).
      expect(frames[1].rawJson, textContentJson);
    });

    test(': comment / heartbeat lines are skipped and produce no frame',
        () async {
      final body = Stream<List<int>>.fromIterable([
        utf8.encode(
          ': keepalive 0\n'
          ': keepalive 1\n'
          'id: 9\n'
          'data: $runStartedJson\n'
          '\n'
          ': keepalive 2\n',
        ),
      ]);
      final fake = _FakeClient(body: body);
      final client = AgentStreamClient(
        pocketBase: _fakePb(),
        httpClient: fake,
      );

      final frames = await client.connect('chat-1', cursor: 0).toList();

      expect(frames, hasLength(1));
      expect(frames.single.seq, 9);
      expect(frames.single.event, isA<RunStartedEvent>());
    });

    test('request URL includes ?cursor=<n> matching connect()', () async {
      final fake = _FakeClient(
        body: Stream<List<int>>.fromIterable([
          utf8.encode('id: 1\ndata: $runStartedJson\n\n'),
        ]),
      );
      final client = AgentStreamClient(
        pocketBase: _fakePb(baseUrl: 'http://pb.local:8090'),
        httpClient: fake,
      );

      await client.connect('chat-xyz', cursor: 42).toList();

      final req = fake.lastRequest;
      expect(req, isNotNull);
      expect(req?.url.toString(),
          'http://pb.local:8090/api/pocketcoder/v1/chats/chat-xyz/stream?cursor=42');
      expect(req?.method, 'GET');
    });

    test('Authorization header equals PocketBase.authStore.token', () async {
      final fake = _FakeClient(
        body: Stream<List<int>>.fromIterable([
          utf8.encode('id: 1\ndata: $runStartedJson\n\n'),
        ]),
      );
      final client = AgentStreamClient(
        pocketBase: _fakePb(),
        httpClient: fake,
      );

      await client.connect('chat-1', cursor: 0).toList();

      expect(fake.lastRequest?.headers['Authorization'], _FakeClient.fakeToken);
    });

    test(
        'returned stream completes when the response body closes '
        '(no hang, no retry)', () async {
      final fake = _FakeClient(
        body: Stream<List<int>>.fromIterable([
          utf8.encode('id: 1\ndata: $runStartedJson\n\n'),
        ]),
      );
      final client = AgentStreamClient(
        pocketBase: _fakePb(),
        httpClient: fake,
      );

      // `.toList()` awaits onDone internally. If AgentStreamClient ever
      // hung instead of completing (e.g. because we accidentally wired
      // up an auto-retry), this would time out the test instead of
      // returning.
      final frames = await client.connect('chat-1', cursor: 0).toList();
      expect(frames, hasLength(1));
      // And nothing happens after the body closes — `connect` has not
      // been called again, so fake.lastRequest is still the original.
      expect(fake.lastRequest, isNotNull);
    });

    test('surfaces non-success HTTP responses without parsing them as SSE',
        () async {
      final client = AgentStreamClient(
        pocketBase: _fakePb(),
        httpClient: _FakeClient(
          body: Stream<List<int>>.fromIterable([utf8.encode('not SSE')]),
          statusCode: 401,
        ),
      );

      expect(
        () => client.connect('chat-1', cursor: 0).toList(),
        throwsA(
          isA<AgentStreamException>().having(
            (error) => error.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });
  });
}
