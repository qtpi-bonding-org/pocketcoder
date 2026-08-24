import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_state.dart';
import 'package:pocketcoder_flutter/domain/chat/i_chat_list_repository.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';

class MockChatListRepository extends Mock implements IChatListRepository {}

void main() {
  late MockChatListRepository repo;
  ChatListCubit? lastCubit;

  ChatListCubit buildCubit() {
    final cubit = ChatListCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  const testChat = Chat(id: 'chat-1', title: 'Hello', user: 'user-1');

  setUp(() {
    repo = MockChatListRepository();
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('ChatListState', () {
    test('default state is idle with an empty chat list', () {
      const state = ChatListState();
      expect(state.status, UiFlowStatus.idle);
      expect(state.chats, isEmpty);
      expect(state.lastCreatedChatId, isNull);
      expect(state.error, isNull);
    });
  });

  group('ChatListCubit.watchChats', () {
    test('reduces stream emissions into success with the chat list', () async {
      final ctrl = StreamController<List<Chat>>.broadcast();
      addTearDown(() async => ctrl.close());
      when(() => repo.watchChats()).thenAnswer((_) => ctrl.stream);

      final cubit = buildCubit();
      cubit.watchChats();

      ctrl.add([testChat]);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, UiFlowStatus.success);
      expect(cubit.state.chats, [testChat]);
      verify(() => repo.watchChats()).called(1);
    });

    test('stream error surfaces as failure with the error in state', () async {
      final ctrl = StreamController<List<Chat>>.broadcast();
      addTearDown(() async => ctrl.close());
      when(() => repo.watchChats()).thenAnswer((_) => ctrl.stream);

      final cubit = buildCubit();
      cubit.watchChats();

      ctrl.addError(Exception('boom'));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.error, isA<Exception>());
    });

    test('clears a pending lastCreatedChatId on the next list emission',
        () async {
      final ctrl = StreamController<List<Chat>>.broadcast();
      addTearDown(() async => ctrl.close());
      when(() => repo.watchChats()).thenAnswer((_) => ctrl.stream);
      when(() => repo.createChat(
            title: any(named: 'title'),
            harness: any(named: 'harness'),
            harnessModelOverride: any(named: 'harnessModelOverride'),
            workspaceOverride: any(named: 'workspaceOverride'),
          )).thenAnswer((_) async => testChat);

      final cubit = buildCubit();
      cubit.watchChats();
      await cubit.createAndOpen();
      expect(cubit.state.lastCreatedChatId, 'chat-1');

      ctrl.add([testChat]);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.lastCreatedChatId, isNull);
    });
  });

  group('ChatListCubit.createAndOpen', () {
    test('creates a chat and sets lastCreatedChatId', () async {
      when(() => repo.createChat(
            title: any(named: 'title'),
            harness: any(named: 'harness'),
            harnessModelOverride: any(named: 'harnessModelOverride'),
            workspaceOverride: any(named: 'workspaceOverride'),
          )).thenAnswer((_) async => testChat);

      final cubit = buildCubit();
      await cubit.createAndOpen();

      verify(() => repo.createChat(
            title: null,
            harness: null,
            harnessModelOverride: null,
            workspaceOverride: null,
          )).called(1);
      expect(cubit.state.lastCreatedChatId, 'chat-1');
      expect(cubit.state.status, UiFlowStatus.success);
    });

    test('surfaces repo failure as state error', () async {
      when(() => repo.createChat(
            title: any(named: 'title'),
            harness: any(named: 'harness'),
            harnessModelOverride: any(named: 'harnessModelOverride'),
            workspaceOverride: any(named: 'workspaceOverride'),
          )).thenThrow(Exception('create failed'));

      final cubit = buildCubit();
      await cubit.createAndOpen();

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.lastCreatedChatId, isNull);
    });

    test('threads harness/harnessModelOverride/workspaceOverride through to repo', () async {
      when(() => repo.createChat(
            title: any(named: 'title'),
            harness: any(named: 'harness'),
            harnessModelOverride: any(named: 'harnessModelOverride'),
            workspaceOverride: any(named: 'workspaceOverride'),
          )).thenAnswer((_) async => testChat);

      final cubit = buildCubit();
      await cubit.createAndOpen(
        title: 'Custom Title',
        harness: 'harness-1',
        harnessModelOverride: 'model-1',
        workspaceOverride: ['ws-1', 'ws-2'],
      );

      verify(() => repo.createChat(
            title: 'Custom Title',
            harness: 'harness-1',
            harnessModelOverride: 'model-1',
            workspaceOverride: ['ws-1', 'ws-2'],
          )).called(1);
      expect(cubit.state.lastCreatedChatId, 'chat-1');
      expect(cubit.state.status, UiFlowStatus.success);
    });
  });

  group('ChatListCubit.checkEmptyAndMaybeAutoCreate', () {
    test('creates and opens a chat when the user has none', () async {
      when(() => repo.hasAnyChats()).thenAnswer((_) async => false);
      when(() => repo.createChat(title: any(named: 'title')))
          .thenAnswer((_) async => testChat);

      final cubit = buildCubit();
      await cubit.checkEmptyAndMaybeAutoCreate();

      verify(() => repo.hasAnyChats()).called(1);
      verify(() => repo.createChat(title: null)).called(1);
      expect(cubit.state.lastCreatedChatId, 'chat-1');
    });

    test('does not create a chat when the user already has some', () async {
      when(() => repo.hasAnyChats()).thenAnswer((_) async => true);

      final cubit = buildCubit();
      await cubit.checkEmptyAndMaybeAutoCreate();

      verify(() => repo.hasAnyChats()).called(1);
      verifyNever(() => repo.createChat(title: any(named: 'title')));
      expect(cubit.state.lastCreatedChatId, isNull);
      expect(cubit.state.status, UiFlowStatus.success);
    });

    test(
        'only runs once per cubit lifetime -- a second call (e.g. from '
        're-entering the chat-list screen, which mounts a fresh adapter '
        'each time even though the cubit itself is app-lifetime) is a '
        'no-op, even if the user has deleted their only chat since',
        () async {
      when(() => repo.hasAnyChats()).thenAnswer((_) async => false);
      when(() => repo.createChat(title: any(named: 'title')))
          .thenAnswer((_) async => testChat);

      final cubit = buildCubit();
      await cubit.checkEmptyAndMaybeAutoCreate();
      verify(() => repo.hasAnyChats()).called(1);
      verify(() => repo.createChat(title: null)).called(1);

      // Simulate re-entering the chat-list screen after the user deleted
      // their only chat -- hasAnyChats() would again say "none", but this
      // must not auto-create a second time.
      await cubit.checkEmptyAndMaybeAutoCreate();

      // No NEW calls beyond the one already verified above.
      verifyNever(() => repo.createChat(title: any(named: 'title')));
      verifyNever(() => repo.hasAnyChats());
    });
  });

  group('ChatListCubit.archive/delete', () {
    test('archive delegates to repo.archiveChat', () async {
      when(() => repo.archiveChat('chat-1')).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.archive('chat-1');

      verify(() => repo.archiveChat('chat-1')).called(1);
      expect(cubit.state.status, UiFlowStatus.success);
    });

    test('delete delegates to repo.deleteChat', () async {
      when(() => repo.deleteChat('chat-1')).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.delete('chat-1');

      verify(() => repo.deleteChat('chat-1')).called(1);
      expect(cubit.state.status, UiFlowStatus.success);
    });
  });
}
