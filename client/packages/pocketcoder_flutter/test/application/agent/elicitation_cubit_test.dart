// Tests for ElicitationCubit (plan Task 12): a fake AgentChatRepository (no
// real stream/cache), asserting that a pending SessionState.elicitation
// surfaces in the cubit state and that submit calls
// repository.respondElicitation with the right args.
import 'dart:async';

import 'package:ag_ui/ag_ui.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/agent/elicitation_cubit.dart';
import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';

class _FakeAgentChatRepository implements AgentChatRepository {
  final Map<String, StreamController<Conversation>> _controllers = {};
  final List<Map<String, Object?>> respondElicitationCalls = [];

  StreamController<Conversation> controllerFor(String chatId) =>
      _controllers.putIfAbsent(chatId, () => StreamController.broadcast());

  @override
  Stream<Conversation> watch(String chatId) => controllerFor(chatId).stream;

  @override
  Stream<List<BaseEvent>> watchRawEvents(String chatId) => const Stream.empty();

  @override
  Future<void> cancelStreams() async {}

  @override
  Future<int> cursorFor(String chatId) async => 0;

  @override
  Future<int> ingestOnce(String chatId, {required int cursor}) async => 0;

  @override
  Future<String> sendPrompt(String chatId, String text,
          {String? messageId}) async =>
      'run-1';

  @override
  Future<void> cancel(String chatId) async {}

  @override
  Future<void> setMode(String chatId, String modeId) async {}

  @override
  Future<void> setConfigOption(String chatId, dynamic req) async {}

  @override
  Future<void> respondPermission(String chatId, String requestId,
      {String? optionId, bool cancelled = false}) async {}

  @override
  Future<void> respondElicitation(
    String chatId,
    String elicitationId,
    ElicitationResponse resp,
  ) async {
    respondElicitationCalls.add({
      'chatId': chatId,
      'elicitationId': elicitationId,
      'resp': resp,
    });
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeAgentChatRepository repo;
  late ElicitationCubit cubit;

  setUp(() {
    repo = _FakeAgentChatRepository();
    cubit = ElicitationCubit(repo);
  });

  tearDown(() async {
    await cubit.close();
  });

  test('a pending elicitation in an emitted Conversation surfaces in state',
      () async {
    cubit.open('chat-1');
    await _settle();

    final pending = {
      'elicitationId': 'elic-42',
      'message': 'Need a name',
      'requestedSchema': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'}
        },
      },
    };
    repo.controllerFor('chat-1').add(
          Conversation(
            sessionState: SessionState(elicitation: pending),
          ),
        );
    await _settle();

    expect(cubit.state.chatId, 'chat-1');
    expect(cubit.state.elicitation, pending);
    expect(cubit.state.status, UiFlowStatus.success);
  });

  test('submit(accept) calls respondElicitation with right ids + payload',
      () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          Conversation(
            sessionState: SessionState(
              elicitation: {
                'elicitationId': 'elic-42',
                'message': 'Need a name',
                'requestedSchema': {
                  'type': 'object',
                  'properties': {
                    'name': {'type': 'string'}
                  },
                },
              },
            ),
          ),
        );
    await _settle();

    final resp = const ElicitationResponse.accept({'name': 'Alice'});
    await cubit.submit(resp);

    expect(repo.respondElicitationCalls, hasLength(1));
    expect(repo.respondElicitationCalls.single['chatId'], 'chat-1');
    expect(repo.respondElicitationCalls.single['elicitationId'], 'elic-42');
    final passed =
        repo.respondElicitationCalls.single['resp'] as ElicitationResponse;
    expect(passed, resp);
    // action discriminator + content match the ACP shape.
    expect(passed.toJson(), {
      'action': 'accept',
      'content': {'name': 'Alice'},
    });
  });

  test('submit(decline) calls respondElicitation with action=decline',
      () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          Conversation(
            sessionState: SessionState(
              elicitation: {
                'elicitationId': 'elic-42',
              },
            ),
          ),
        );
    await _settle();

    await cubit.submit(const ElicitationResponse.decline());

    expect(repo.respondElicitationCalls, hasLength(1));
    final passed =
        repo.respondElicitationCalls.single['resp'] as ElicitationResponse;
    expect(passed.toJson(), {'action': 'decline'});
  });

  test('submit(cancel) calls respondElicitation with action=cancel', () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          Conversation(
            sessionState: SessionState(
              elicitation: {
                'elicitationId': 'elic-42',
              },
            ),
          ),
        );
    await _settle();

    await cubit.submit(const ElicitationResponse.cancel());

    expect(repo.respondElicitationCalls, hasLength(1));
    final passed =
        repo.respondElicitationCalls.single['resp'] as ElicitationResponse;
    expect(passed.toJson(), {'action': 'cancel'});
  });

  test('submit is a safe no-op when no elicitation is pending', () async {
    cubit.open('chat-1');
    await _settle();

    await cubit.submit(const ElicitationResponse.cancel());

    expect(repo.respondElicitationCalls, isEmpty);
    expect(cubit.state.elicitation, isNull);
  });

  test('a queued old-chat emission cannot update the newly opened chat',
      () async {
    cubit.open('chat-1');
    repo.controllerFor('chat-1').add(Conversation(
          sessionState: SessionState(elicitation: {'elicitationId': 'old'}),
        ));
    cubit.open('chat-2');
    await _settle();

    expect(cubit.state.chatId, 'chat-2');
    expect(cubit.state.elicitation, isNull);
  });
}
