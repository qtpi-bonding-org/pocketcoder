import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/exceptions/chat_list_exception.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/infrastructure/chat/chat_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/chat/chat_list_repository.dart';

class MockChatDao extends Mock implements ChatDao {}

class MockAuthRepository extends Mock implements IAuthRepository {}

class _FakeChat extends Fake implements Chat {}

void main() {
  late ChatListRepository repo;
  late MockChatDao dao;
  late MockAuthRepository auth;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    dao = MockChatDao();
    auth = MockAuthRepository();
    repo = ChatListRepository(dao, auth);
  });

  group('ChatListRepository.watchChats', () {
    test('watches chats filtered to non-archived, sorted by -last_active', () {
      when(() => dao.watch(
            filter: 'archived != true',
            sort: '-last_active',
          )).thenAnswer((_) => const Stream.empty());

      repo.watchChats();

      verify(() => dao.watch(
            filter: 'archived != true',
            sort: '-last_active',
          )).called(1);
    });
  });

  group('ChatListRepository.hasAnyChats', () {
    test('returns true when the network-only fetch finds chats', () async {
      when(() => dao.getFullList(
            filter: 'archived != true',
            requestPolicy: RequestPolicy.networkOnly,
          )).thenAnswer((_) async => [_FakeChat()]);

      final result = await repo.hasAnyChats();

      expect(result, isTrue);
    });

    test('returns false when the network-only fetch finds none', () async {
      when(() => dao.getFullList(
            filter: 'archived != true',
            requestPolicy: RequestPolicy.networkOnly,
          )).thenAnswer((_) async => []);

      final result = await repo.hasAnyChats();

      expect(result, isFalse);
    });

    test('wraps failures in ChatListException', () async {
      when(() => dao.getFullList(
            filter: 'archived != true',
            requestPolicy: RequestPolicy.networkOnly,
          )).thenThrow(Exception('offline'));

      await expectLater(
        () => repo.hasAnyChats(),
        throwsA(isA<ChatListException>()),
      );
    });
  });

  group('ChatListRepository.createChat', () {
    test('creates a chat with the given title and current user id', () async {
      when(() => auth.currentUserId).thenReturn('user-1');
      when(() => dao.save(any(), any())).thenAnswer(
        (_) async => const Chat(id: 'chat-1', title: 'My Chat', user: 'user-1'),
      );

      final result = await repo.createChat(title: 'My Chat');

      verify(() => dao.save(null, {
            'title': 'My Chat',
            'user': 'user-1',
          })).called(1);
      expect(result.id, 'chat-1');
    });

    test('defaults title to "New Chat" when none given', () async {
      when(() => auth.currentUserId).thenReturn('user-1');
      when(() => dao.save(any(), any())).thenAnswer(
        (_) async => const Chat(id: 'chat-1', title: 'New Chat', user: 'user-1'),
      );

      await repo.createChat();

      verify(() => dao.save(null, {
            'title': 'New Chat',
            'user': 'user-1',
          })).called(1);
    });

    test('wraps failures in ChatListException', () async {
      when(() => auth.currentUserId).thenReturn('user-1');
      when(() => dao.save(any(), any())).thenThrow(Exception('boom'));

      await expectLater(
        () => repo.createChat(title: 'x'),
        throwsA(isA<ChatListException>()),
      );
    });

    test('includes harness when given', () async {
      when(() => auth.currentUserId).thenReturn('user-1');
      when(() => dao.save(any(), any())).thenAnswer(
        (_) async => const Chat(id: 'chat-1', title: 'My Chat', user: 'user-1'),
      );

      await repo.createChat(title: 'My Chat', harness: 'harness-1');

      verify(() => dao.save(null, {
            'title': 'My Chat',
            'user': 'user-1',
            'harness': 'harness-1',
          })).called(1);
    });

    test('includes harnessModelOverride when given', () async {
      when(() => auth.currentUserId).thenReturn('user-1');
      when(() => dao.save(any(), any())).thenAnswer(
        (_) async => const Chat(id: 'chat-1', title: 'My Chat', user: 'user-1'),
      );

      await repo.createChat(title: 'My Chat', harnessModelOverride: 'hm-1');

      verify(() => dao.save(null, {
            'title': 'My Chat',
            'user': 'user-1',
            'harness_model_override': 'hm-1',
          })).called(1);
    });

    test('includes workspace_override only when non-null, never as an empty stand-in', () async {
      when(() => auth.currentUserId).thenReturn('user-1');
      when(() => dao.save(any(), any())).thenAnswer(
        (_) async => const Chat(id: 'chat-1', title: 'My Chat', user: 'user-1'),
      );

      await repo.createChat(title: 'My Chat', workspaceOverride: ['/workspace/proj']);

      verify(() => dao.save(null, {
            'title': 'My Chat',
            'user': 'user-1',
            'workspace_override': ['/workspace/proj'],
          })).called(1);
    });

    test('omits harness/harnessModelOverride/workspace_override entirely when all null', () async {
      when(() => auth.currentUserId).thenReturn('user-1');
      when(() => dao.save(any(), any())).thenAnswer(
        (_) async => const Chat(id: 'chat-1', title: 'My Chat', user: 'user-1'),
      );

      await repo.createChat(title: 'My Chat');

      verify(() => dao.save(null, {
            'title': 'My Chat',
            'user': 'user-1',
          })).called(1);
    });
  });

  group('ChatListRepository.archiveChat', () {
    test('sets archived true via dao.save', () async {
      when(() => dao.save('chat-1', {'archived': true})).thenAnswer(
        (_) async => const Chat(id: 'chat-1', title: 'x', user: 'u', archived: true),
      );

      await repo.archiveChat('chat-1');

      verify(() => dao.save('chat-1', {'archived': true})).called(1);
    });
  });

  group('ChatListRepository.deleteChat', () {
    test('deletes via dao.delete', () async {
      when(() => dao.delete('chat-1')).thenAnswer((_) async {});

      await repo.deleteChat('chat-1');

      verify(() => dao.delete('chat-1')).called(1);
    });
  });
}
