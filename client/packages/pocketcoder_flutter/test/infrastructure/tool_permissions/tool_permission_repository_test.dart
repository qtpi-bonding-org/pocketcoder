import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/infrastructure/tool_permissions/tool_permission_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/tool_permissions/tool_permission_repository.dart';

class MockToolPermissionDao extends Mock implements ToolPermissionDao {}

class _FakeToolPermission extends Fake implements ToolPermission {}

void main() {
  late ToolPermissionRepository repo;
  late MockToolPermissionDao dao;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    dao = MockToolPermissionDao();
    repo = ToolPermissionRepository(dao);
  });

  group('ToolPermissionRepository.watchRules', () {
    test('watches with poco_config="" filter, sorted by tool', () async {
      when(() =>
              dao.watch(filter: any(named: 'filter'), sort: any(named: 'sort')))
          .thenAnswer((_) => const Stream.empty());

      repo.watchRules();

      verify(() => dao.watch(filter: 'poco_config = ""', sort: 'tool'))
          .called(1);
    });
  });

  group('ToolPermissionRepository.createRule', () {
    test('creates a tool_permissions row with pattern "*" and active true',
        () async {
      when(() => dao.save(any(), any()))
          .thenAnswer((_) async => _FakeToolPermission());

      await repo.createRule(tool: 'bash', action: 'allow');

      verify(() => dao.save(null, {
            'tool': 'bash',
            'pattern': '*',
            'action': 'allow',
            'active': true,
          })).called(1);
    });

    test('wraps failures in ToolPermissionsException', () async {
      when(() => dao.save(any(), any())).thenThrow(Exception('boom'));

      await expectLater(
        () => repo.createRule(tool: 'bash', action: 'allow'),
        throwsA(isA<ToolPermissionsException>()),
      );
    });
  });

  group('ToolPermissionRepository.updateAction', () {
    test('saves only the action field', () async {
      when(() => dao.save(any(), any()))
          .thenAnswer((_) async => _FakeToolPermission());

      await repo.updateAction('rule-1', 'deny');

      verify(() => dao.save('rule-1', {'action': 'deny'})).called(1);
    });

    test('wraps failures in ToolPermissionsException', () async {
      when(() => dao.save(any(), any())).thenThrow(Exception('boom'));

      await expectLater(
        () => repo.updateAction('rule-1', 'deny'),
        throwsA(isA<ToolPermissionsException>()),
      );
    });
  });

  group('ToolPermissionRepository.setActive', () {
    test('saves only the active field', () async {
      when(() => dao.save(any(), any()))
          .thenAnswer((_) async => _FakeToolPermission());

      await repo.setActive('rule-1', false);

      verify(() => dao.save('rule-1', {'active': false})).called(1);
    });

    test('wraps failures in ToolPermissionsException', () async {
      when(() => dao.save(any(), any())).thenThrow(Exception('boom'));

      await expectLater(
        () => repo.setActive('rule-1', false),
        throwsA(isA<ToolPermissionsException>()),
      );
    });
  });
}
