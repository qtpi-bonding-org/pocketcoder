// Tests for NotificationRuleRepository.
//
// Mirrors `tool_permission_repository_test.dart`'s structure: mocks the
// DAO with mocktail, exercises the repository's watch/set logic, and
// wraps failures in RepositoryException. The PocketBase client is mocked
// because the repository only needs `authStore.record.id` from it.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/models/notification_rule.dart';
import 'package:pocketcoder_flutter/infrastructure/notifications/notification_rule_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/notifications/notification_rule_repository.dart';

class MockPocketBase extends Mock implements PocketBase {}

class MockNotificationRuleDao extends Mock implements NotificationRuleDao {}

class _FakeNotificationRule extends Fake implements NotificationRule {
  _FakeNotificationRule({this.rules = const {}});
  @override
  String get id => 'rule-1';
  @override
  final dynamic rules;
}

class _AuthedAuthStore extends Fake implements AuthStore {
  @override
  RecordModel? get record => _UserRecord();
}

class _UserRecord extends Fake implements RecordModel {
  @override
  String get id => 'user-1';
}

class _AnonymousAuthStore extends Fake implements AuthStore {
  @override
  RecordModel? get record => null;
}

void main() {
  late NotificationRuleRepository repo;
  late MockPocketBase pb;
  late MockNotificationRuleDao dao;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    pb = MockPocketBase();
    dao = MockNotificationRuleDao();
    when(() => pb.authStore).thenReturn(_AuthedAuthStore());
    repo = NotificationRuleRepository(dao, pb);
  });

  group('NotificationRuleRepository.watchRules', () {
    test('yields empty map when no notification_rules row exists', () async {
      when(() => dao.watch(filter: any(named: 'filter')))
          .thenAnswer((_) => Stream.value(const <NotificationRule>[]));

      expect(await repo.watchRules().first, isEmpty);
      verify(() => dao.watch(filter: 'user = "user-1"')).called(1);
    });

    test('maps the first row rules JSON to a Map<String, bool>', () async {
      when(() => dao.watch(filter: any(named: 'filter')))
          .thenAnswer((_) => Stream.value([
                _FakeNotificationRule(
                  rules: {'chat_reply': true, 'schedule': false},
                ),
              ]));

      final result = await repo.watchRules().first;
      expect(result['chat_reply'], isTrue);
      expect(result['schedule'], isFalse);
      expect(result.containsKey('task_complete'), isFalse);
    });

    test('yields empty map when user is not authenticated', () async {
      final anonymousPb = MockPocketBase();
      final anonymousDao = MockNotificationRuleDao();
      when(() => anonymousPb.authStore).thenReturn(_AnonymousAuthStore());
      final anonymousRepo =
          NotificationRuleRepository(anonymousDao, anonymousPb);

      expect(await anonymousRepo.watchRules().first, isEmpty);
      verifyNever(() => anonymousDao.watch(filter: any(named: 'filter')));
    });
  });

  group('NotificationRuleRepository.setTypeEnabled', () {
    test('creates a new notification_rules row when none exists', () async {
      when(() => dao.getFullList(filter: any(named: 'filter')))
          .thenAnswer((_) async => const <NotificationRule>[]);
      when(() => dao.save(any(), any()))
          .thenAnswer((_) async => _FakeNotificationRule());

      await repo.setTypeEnabled('chat_reply', true);

      verify(() => dao.getFullList(filter: 'user = "user-1"')).called(1);
      verify(() => dao.save(null, {
            'user': 'user-1',
            'rules': {'chat_reply': true},
          })).called(1);
    });

    test('merges into the existing rules map and updates the row', () async {
      when(() => dao.getFullList(filter: any(named: 'filter')))
          .thenAnswer((_) async => <NotificationRule>[
                _FakeNotificationRule(
                  rules: {'chat_reply': true, 'schedule': true},
                ),
              ]);
      when(() => dao.save(any(), any()))
          .thenAnswer((_) async => _FakeNotificationRule());

      await repo.setTypeEnabled('schedule', false);

      verify(() => dao.save('rule-1', {
            'rules': {'chat_reply': true, 'schedule': false},
          })).called(1);
    });

    test('wraps failures in RepositoryException', () async {
      when(() => dao.getFullList(filter: any(named: 'filter')))
          .thenThrow(Exception('boom'));

      await expectLater(
        () => repo.setTypeEnabled('chat_reply', false),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('no-op when user is not authenticated', () async {
      final anonymousPb = MockPocketBase();
      final anonymousDao = MockNotificationRuleDao();
      when(() => anonymousPb.authStore).thenReturn(_AnonymousAuthStore());
      final anonymousRepo =
          NotificationRuleRepository(anonymousDao, anonymousPb);

      await anonymousRepo.setTypeEnabled('chat_reply', false);

      verifyNever(
        () => anonymousDao.getFullList(filter: any(named: 'filter')),
      );
      verifyNever(() => anonymousDao.save(any(), any()));
    });
  });
}
