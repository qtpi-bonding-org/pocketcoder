// Up-channel parity test (plan Task 9): for each AgentActionsApi method,
// capture the JSON body it actually POSTs (via a fake http.Client injected
// into PocketBase) and assert it matches the ACP body shape c1 accepts
// after Task 4's up-channel conformance fix. This is the Dart <-> Go-SDK
// up-drift gate — a future acp_dart bump that changes field names breaks
// here first.
import 'dart:async';
import 'dart:convert';

import 'package:acp_dart/acp_dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_actions_api.dart';

/// Captures the most recent request and replies with a canned status +
/// JSON body. Default: 202 Accepted with an empty JSON object (the shape
/// most of these endpoints return per spec §10).
class _FakeClient extends http.BaseClient {
  http.BaseRequest? lastRequest;
  int nextStatusCode = 202;
  Map<String, dynamic> nextResponseBody = const {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    final bytes = utf8.encode(jsonEncode(nextResponseBody));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      nextStatusCode,
      request: request,
      headers: const {'Content-Type': 'application/json'},
    );
  }
}

Map<String, dynamic> _lastBody(_FakeClient fake) {
  final req = fake.lastRequest;
  if (req is! http.Request || req.body.isEmpty) return const {};
  return jsonDecode(req.body) as Map<String, dynamic>;
}

void main() {
  late _FakeClient fake;
  late PocketBase pb;
  late AgentActionsApi api;

  setUp(() {
    fake = _FakeClient();
    pb = PocketBase('http://pb.local', httpClientFactory: () => fake);
    api = AgentActionsApi(pb);
  });

  group('prompt', () {
    test('POSTs {"prompt":[{"type":"text","text":"..."}]} with no sessionId',
        () async {
      fake.nextResponseBody = {'runId': 'run-123'};
      final runId = await api.prompt('chat-1', 'hi');

      expect(runId, 'run-123');
      expect(fake.lastRequest?.url.path, '/api/pocketcoder/chats/chat-1/session/prompt');
      final body = _lastBody(fake);
      expect(body.containsKey('sessionId'), isFalse);
      // acp_dart's TextContentBlock.toJson also emits a nullable
      // `annotations` field (omitted here since ACP marks it optional and
      // c1 ignores unset/extra fields) — assert on the fields the bats
      // acceptance suite actually checks (type + text).
      final block = (body['prompt'] as List).single as Map<String, dynamic>;
      expect(block['type'], 'text');
      expect(block['text'], 'hi');
    });
  });

  group('cancel', () {
    test('POSTs {} to session/cancel', () async {
      await api.cancel('chat-1');
      expect(fake.lastRequest?.url.path, '/api/pocketcoder/chats/chat-1/session/cancel');
      expect(_lastBody(fake), <String, dynamic>{});
    });
  });

  group('setMode', () {
    test('POSTs {"modeId":"..."} with no sessionId', () async {
      await api.setMode('chat-1', 'chat');
      expect(fake.lastRequest?.url.path, '/api/pocketcoder/chats/chat-1/session/set_mode');
      final body = _lastBody(fake);
      expect(body.containsKey('sessionId'), isFalse);
      expect(body['modeId'], 'chat');
    });
  });

  group('setConfigOption', () {
    test('POSTs {"configId":"...","value":"..."} with no sessionId', () async {
      await api.setConfigOption(
        'chat-1',
        SetSessionConfigOptionRequest(
          sessionId: 'ignored',
          configId: 'mode',
          value: 'approve',
        ),
      );
      expect(fake.lastRequest?.url.path,
          '/api/pocketcoder/chats/chat-1/session/set_config_option');
      final body = _lastBody(fake);
      expect(body.containsKey('sessionId'), isFalse);
      expect(body['configId'], 'mode');
      expect(body['value'], 'approve');
    });
  });

  group('respondPermission', () {
    test('selected outcome POSTs {"outcome":{"outcome":"selected","optionId":"x"}}',
        () async {
      await api.respondPermission('chat-1', 'req-1', optionId: 'allow_once');
      expect(fake.lastRequest?.url.path,
          '/api/pocketcoder/chats/chat-1/session/request_permission/req-1');
      final body = _lastBody(fake);
      expect(body.containsKey('sessionId'), isFalse);
      expect(body['outcome'], {'outcome': 'selected', 'optionId': 'allow_once'});
    });

    test('cancelled outcome POSTs {"outcome":{"outcome":"cancelled"}}',
        () async {
      await api.respondPermission('chat-1', 'req-1', cancelled: true);
      final body = _lastBody(fake);
      expect(body['outcome'], {'outcome': 'cancelled'});
    });
  });

  group('respondElicitation', () {
    test('accept POSTs {"action":"accept","content":{...}}', () async {
      await api.respondElicitation(
        'chat-1',
        'elicit-1',
        const ElicitationResponse.accept({'answer': 'yes'}),
      );
      expect(fake.lastRequest?.url.path,
          '/api/pocketcoder/chats/chat-1/session/elicitation/elicit-1');
      final body = _lastBody(fake);
      expect(body, {
        'action': 'accept',
        'content': {'answer': 'yes'},
      });
    });

    test('decline POSTs {"action":"decline"}', () async {
      await api.respondElicitation(
        'chat-1',
        'elicit-1',
        const ElicitationResponse.decline(),
      );
      expect(_lastBody(fake), {'action': 'decline'});
    });

    test('cancel POSTs {"action":"cancel"}', () async {
      await api.respondElicitation(
        'chat-1',
        'elicit-1',
        const ElicitationResponse.cancel(),
      );
      expect(_lastBody(fake), {'action': 'cancel'});
    });
  });

  group('HTTP status -> typed failure mapping (spec §10)', () {
    test('400 -> BadRequestFailure', () async {
      fake.nextStatusCode = 400;
      fake.nextResponseBody = {'message': 'bad request'};
      await expectLater(
        api.cancel('chat-1'),
        throwsA(isA<BadRequestFailure>()),
      );
    });

    test('401 -> UnauthenticatedFailure', () async {
      fake.nextStatusCode = 401;
      fake.nextResponseBody = {'message': 'unauthenticated'};
      await expectLater(
        api.cancel('chat-1'),
        throwsA(isA<UnauthenticatedFailure>()),
      );
    });

    test('404 -> NotFoundFailure', () async {
      fake.nextStatusCode = 404;
      fake.nextResponseBody = {'message': 'not found'};
      await expectLater(
        api.cancel('chat-1'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('409 -> RunInProgressFailure', () async {
      fake.nextStatusCode = 409;
      fake.nextResponseBody = {'message': 'run in progress'};
      await expectLater(
        api.prompt('chat-1', 'hi'),
        throwsA(isA<RunInProgressFailure>()),
      );
    });

    test('503 -> AgentUnavailableFailure', () async {
      fake.nextStatusCode = 503;
      fake.nextResponseBody = {'message': 'agent unavailable'};
      await expectLater(
        api.cancel('chat-1'),
        throwsA(isA<AgentUnavailableFailure>()),
      );
    });
  });
}
