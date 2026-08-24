// Tests for PermissionCubit (plan Task 12): a fake AgentChatRepository
// (no real stream/cache), asserting that a pending SessionState.permission
// surfaces in the cubit state and that authorize/deny call
// repository.respondPermission with the right args. authorize/deny are a
// safe no-op when nothing is pending.
import 'dart:async';

import 'package:ag_ui/ag_ui.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/agent/permission_cubit.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';

class _FakeAgentChatRepository implements AgentChatRepository {
  final Map<String, StreamController<Conversation>> _controllers = {};
  final List<Map<String, Object?>> respondPermissionCalls = [];

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
  Future<String> sendPrompt(String chatId, String text) async => 'run-1';

  @override
  Future<void> cancel(String chatId) async {}

  @override
  Future<void> setMode(String chatId, String modeId) async {}

  @override
  Future<void> setConfigOption(String chatId, dynamic req) async {}

  @override
  Future<void> respondPermission(
    String chatId,
    String requestId, {
    String? optionId,
    bool cancelled = false,
  }) async {
    respondPermissionCalls.add({
      'chatId': chatId,
      'requestId': requestId,
      'optionId': optionId,
      'cancelled': cancelled,
    });
  }

  @override
  Future<void> respondElicitation(
      String chatId, String elicitationId, dynamic resp) async {}
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeAgentChatRepository repo;
  late PermissionCubit cubit;

  setUp(() {
    repo = _FakeAgentChatRepository();
    cubit = PermissionCubit(repo);
  });

  tearDown(() async {
    await cubit.close();
  });

  test('a pending permission in an emitted Conversation surfaces in state',
      () async {
    cubit.open('chat-1');
    await _settle();

    final pending = {
      'requestId': 'req-42',
      'toolCall': {'title': 'run shell'},
      'options': [
        {'optionId': 'allow', 'name': 'Allow', 'kind': 'allow_once'},
      ],
    };
    repo.controllerFor('chat-1').add(
          Conversation(
            sessionState: SessionState(permission: pending),
          ),
        );
    await _settle();

    expect(cubit.state.chatId, 'chat-1');
    expect(cubit.state.permission, pending);
    expect(cubit.state.status, UiFlowStatus.success);
  });

  test('authorize calls respondPermission with the right requestId/optionId',
      () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          Conversation(
            sessionState: SessionState(
              permission: {
                'requestId': 'req-42',
                'options': [
                  {'optionId': 'allow', 'name': 'Allow', 'kind': 'allow_once'},
                ],
              },
            ),
          ),
        );
    await _settle();

    await cubit.authorize('allow');

    expect(repo.respondPermissionCalls, hasLength(1));
    expect(repo.respondPermissionCalls.single['chatId'], 'chat-1');
    expect(repo.respondPermissionCalls.single['requestId'], 'req-42');
    expect(repo.respondPermissionCalls.single['optionId'], 'allow');
    expect(repo.respondPermissionCalls.single['cancelled'], false);
  });

  test('deny calls respondPermission with cancelled:true', () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          Conversation(
            sessionState: SessionState(
              permission: {
                'requestId': 'req-42',
                'options': [
                  {'optionId': 'allow', 'name': 'Allow', 'kind': 'allow_once'},
                ],
              },
            ),
          ),
        );
    await _settle();

    await cubit.deny();

    expect(repo.respondPermissionCalls, hasLength(1));
    expect(repo.respondPermissionCalls.single['chatId'], 'chat-1');
    expect(repo.respondPermissionCalls.single['requestId'], 'req-42');
    expect(repo.respondPermissionCalls.single['optionId'], isNull);
    expect(repo.respondPermissionCalls.single['cancelled'], true);
  });

  test('authorize is a safe no-op when no permission is pending', () async {
    cubit.open('chat-1');
    await _settle();

    await cubit.authorize('allow');

    expect(repo.respondPermissionCalls, isEmpty);
    expect(cubit.state.permission, isNull);
  });

  test('deny is a safe no-op when no permission is pending', () async {
    cubit.open('chat-1');
    await _settle();

    await cubit.deny();

    expect(repo.respondPermissionCalls, isEmpty);
    expect(cubit.state.permission, isNull);
  });

  test('a requestId supplied by a stale permission card is rejected', () async {
    cubit.open('chat-1');
    repo.controllerFor('chat-1').add(Conversation(
          sessionState: SessionState(
            permission: {'requestId': 'current', 'options': []},
          ),
        ));
    await _settle();

    await cubit.authorize('allow', requestId: 'stale');
    await cubit.deny(requestId: 'stale');

    expect(repo.respondPermissionCalls, isEmpty);
  });

  test('a queued old-chat emission cannot update the newly opened chat',
      () async {
    cubit.open('chat-1');
    repo.controllerFor('chat-1').add(Conversation(
          sessionState: SessionState(permission: {'requestId': 'old'}),
        ));
    cubit.open('chat-2');
    await _settle();

    expect(cubit.state.chatId, 'chat-2');
    expect(cubit.state.permission, isNull);
  });

  test('re-opening with a different chatId replaces the subscription',
      () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          Conversation(
            sessionState: SessionState(
              permission: {'requestId': 'req-1'},
            ),
          ),
        );
    await _settle();
    expect(cubit.state.permission?['requestId'], 'req-1');

    cubit.open('chat-2');
    await _settle();

    repo.controllerFor('chat-2').add(
          Conversation(
            sessionState: SessionState(
              permission: {'requestId': 'req-2'},
            ),
          ),
        );
    await _settle();

    expect(cubit.state.chatId, 'chat-2');
    expect(cubit.state.permission?['requestId'], 'req-2');
  });
}
