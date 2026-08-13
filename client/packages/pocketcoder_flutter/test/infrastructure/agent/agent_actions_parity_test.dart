// Up-channel parity test (plan Task 9): for each AgentActionsApi method,
// capture the JSON body it actually POSTs (via a fake http.Client injected
// into PocketBase) and assert it matches the ACP body shape c1 accepts
// after Task 4's up-channel conformance fix. This is the Dart <-> Go-SDK
// up-drift gate — a future acp_dart bump that changes field names breaks
// here first.
import 'package:acp_dart/acp_dart.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_actions_api.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';

import '../../helpers/capturing_dio_adapter.dart';

void main() {
  late CapturingDioAdapter adapter;
  late int nextStatusCode;
  late Map<String, dynamic> nextResponseBody;
  late AgentActionsApi api;

  setUp(() {
    nextStatusCode = 202;
    nextResponseBody = const {};
    adapter = CapturingDioAdapter(
      (_, __) => jsonResponse(
        nextResponseBody,
        statusCode: nextStatusCode,
      ),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://pb.local'))
      ..httpClientAdapter = adapter;
    api = AgentActionsApi(PocketCoderApiClient(dio: dio));
  });

  group('prompt', () {
    test('POSTs {"prompt":[{"type":"text","text":"..."}]} with no sessionId',
        () async {
      nextResponseBody = {'runId': 'run-123'};
      final runId = await api.prompt('chat-1', 'hi');

      expect(runId, 'run-123');
      expect(adapter.lastRequest?.path,
          '/api/pocketcoder/v1/chats/chat-1/session/prompt');
      final body = adapter.lastJsonBody;
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
      expect(adapter.lastRequest?.path,
          '/api/pocketcoder/v1/chats/chat-1/session/cancel');
      expect(adapter.lastJsonBody, <String, dynamic>{});
    });
  });

  group('setMode', () {
    test('POSTs {"modeId":"..."} with no sessionId', () async {
      await api.setMode('chat-1', 'chat');
      expect(adapter.lastRequest?.path,
          '/api/pocketcoder/v1/chats/chat-1/session/set-mode');
      final body = adapter.lastJsonBody;
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
      expect(adapter.lastRequest?.path,
          '/api/pocketcoder/v1/chats/chat-1/session/set-config-option');
      final body = adapter.lastJsonBody;
      expect(body.containsKey('sessionId'), isFalse);
      expect(body['configId'], 'mode');
      expect(body['value'], 'approve');
    });
  });

  group('respondPermission', () {
    test(
        'selected outcome POSTs {"outcome":{"outcome":"selected","optionId":"x"}}',
        () async {
      await api.respondPermission('chat-1', 'req-1', optionId: 'allow_once');
      expect(adapter.lastRequest?.path,
          '/api/pocketcoder/v1/chats/chat-1/session/request-permission/req-1');
      final body = adapter.lastJsonBody;
      expect(body.containsKey('sessionId'), isFalse);
      expect(
          body['outcome'], {'outcome': 'selected', 'optionId': 'allow_once'});
    });

    test('cancelled outcome POSTs {"outcome":{"outcome":"cancelled"}}',
        () async {
      await api.respondPermission('chat-1', 'req-1', cancelled: true);
      final body = adapter.lastJsonBody;
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
      expect(adapter.lastRequest?.path,
          '/api/pocketcoder/v1/chats/chat-1/session/elicitation/elicit-1');
      final body = adapter.lastJsonBody;
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
      expect(adapter.lastJsonBody, {'action': 'decline'});
    });

    test('cancel POSTs {"action":"cancel"}', () async {
      await api.respondElicitation(
        'chat-1',
        'elicit-1',
        const ElicitationResponse.cancel(),
      );
      expect(adapter.lastJsonBody, {'action': 'cancel'});
    });
  });

  group('HTTP status -> typed failure mapping (spec §10)', () {
    test('400 -> BadRequestFailure', () async {
      nextStatusCode = 400;
      nextResponseBody = {'message': 'bad request'};
      await expectLater(
        api.cancel('chat-1'),
        throwsA(isA<BadRequestFailure>()),
      );
    });

    test('401 -> UnauthenticatedFailure', () async {
      nextStatusCode = 401;
      nextResponseBody = {'message': 'unauthenticated'};
      await expectLater(
        api.cancel('chat-1'),
        throwsA(isA<UnauthenticatedFailure>()),
      );
    });

    test('404 -> NotFoundFailure', () async {
      nextStatusCode = 404;
      nextResponseBody = {'message': 'not found'};
      await expectLater(
        api.cancel('chat-1'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('409 -> RunInProgressFailure', () async {
      nextStatusCode = 409;
      nextResponseBody = {'message': 'run in progress'};
      await expectLater(
        api.prompt('chat-1', 'hi'),
        throwsA(isA<RunInProgressFailure>()),
      );
    });

    test('503 -> AgentUnavailableFailure', () async {
      nextStatusCode = 503;
      nextResponseBody = {'message': 'agent unavailable'};
      await expectLater(
        api.cancel('chat-1'),
        throwsA(isA<AgentUnavailableFailure>()),
      );
    });
  });
}
