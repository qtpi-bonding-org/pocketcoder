// Tests for ChatMonitoringCubit: a fake IChatListRepository (no real
// stream/dao), asserting that a watched chat's `monitored` flag surfaces
// in state and that toggle() calls repository.setMonitored with the
// flipped value.
import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketcoder_flutter/application/chat/chat_monitoring_cubit.dart';
import 'package:pocketcoder_flutter/domain/chat/i_chat_list_repository.dart';
import 'package:pocketcoder_flutter/domain/live_activities/i_live_activity_ender.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';

class _FakeChatListRepository implements IChatListRepository {
  final Map<String, StreamController<Chat?>> _controllers = {};
  final List<Map<String, Object?>> setMonitoredCalls = [];

  StreamController<Chat?> controllerFor(String chatId) =>
      _controllers.putIfAbsent(chatId, () => StreamController.broadcast());

  @override
  Stream<Chat?> watchChat(String id) => controllerFor(id).stream;

  @override
  Future<void> setMonitored(String id, bool monitored) async {
    setMonitoredCalls.add({'id': id, 'monitored': monitored});
  }

  @override
  Stream<List<Chat>> watchChats() => const Stream.empty();

  @override
  Future<bool> hasAnyChats() async => true;

  @override
  Future<Chat> createChat({
    String? title,
    String? harness,
    String? harnessModelOverride,
    String? ollamaModelOverride,
    List<String>? workspaceOverride,
  }) async =>
      const Chat(id: 'chat-x', title: 'x', user: 'u');

  @override
  Future<void> archiveChat(String id) async {}

  @override
  Future<void> deleteChat(String id) async {}
}

class _FakeLiveActivityEnder implements ILiveActivityEnder {
  final calls = <String>[];

  @override
  Future<void> endForChat(String chatId) async {
    calls.add(chatId);
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeChatListRepository repo;
  late ChatMonitoringCubit cubit;

  setUp(() {
    repo = _FakeChatListRepository();
    cubit = ChatMonitoringCubit(repo);
  });

  tearDown(() async {
    await cubit.close();
    if (GetIt.instance.isRegistered<ILiveActivityEnder>()) {
      await GetIt.instance.unregister<ILiveActivityEnder>();
    }
  });

  test('an emitted chat surfaces its monitored flag in state', () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          const Chat(id: 'chat-1', title: 'x', user: 'u', monitored: true),
        );
    await _settle();

    expect(cubit.state.chatId, 'chat-1');
    expect(cubit.state.monitored, isTrue);
    expect(cubit.state.status, UiFlowStatus.success);
  });

  test('a null monitored flag surfaces as false', () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          const Chat(id: 'chat-1', title: 'x', user: 'u'),
        );
    await _settle();

    expect(cubit.state.monitored, isFalse);
  });

  test('toggle flips the current value and calls repository.setMonitored',
      () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          const Chat(id: 'chat-1', title: 'x', user: 'u', monitored: false),
        );
    await _settle();

    await cubit.toggle();

    expect(repo.setMonitoredCalls, [
      {'id': 'chat-1', 'monitored': true},
    ]);
    expect(cubit.state.monitored, isTrue);
  });

  test('toggle again flips back to false', () async {
    cubit.open('chat-1');
    await _settle();

    repo.controllerFor('chat-1').add(
          const Chat(id: 'chat-1', title: 'x', user: 'u', monitored: true),
        );
    await _settle();

    await cubit.toggle();

    expect(repo.setMonitoredCalls.last, {'id': 'chat-1', 'monitored': false});
    expect(cubit.state.monitored, isFalse);
  });

  test('turning monitoring off ends the optional Live Activity', () async {
    final ender = _FakeLiveActivityEnder();
    GetIt.instance.registerSingleton<ILiveActivityEnder>(ender);
    cubit.open('chat-1');
    await _settle();
    repo.controllerFor('chat-1').add(
          const Chat(id: 'chat-1', title: 'x', user: 'u', monitored: true),
        );
    await _settle();

    await cubit.toggle();

    expect(repo.setMonitoredCalls.last, {'id': 'chat-1', 'monitored': false});
    expect(ender.calls, ['chat-1']);
  });
}
