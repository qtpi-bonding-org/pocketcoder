import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/infrastructure/agent_config/agent_config_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/permission_modes/permission_mode_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/permission_modes/tool_permission_dao.dart';

class MockPermissionModeDao extends Mock implements PermissionModeDao {}

class MockToolPermissionDao extends Mock implements ToolPermissionDao {}

class MockAuthRepository extends Mock implements IAuthRepository {}

class _FakePermissionMode extends Fake implements PermissionMode {}

class _FakeToolPermission extends Fake implements ToolPermission {}

void main() {
  late PermissionModeRepository repo;
  late MockPermissionModeDao modeDao;
  late MockToolPermissionDao ruleDao;
  late MockAuthRepository auth;

  final sourceMode = PermissionMode(
    id: 'mode-read',
    name: 'read',
    description: 'read-only',
    baseSessionMode: PermissionModeBaseSessionMode.approve,
    isSystem: true,
  );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(_FakePermissionMode());
    registerFallbackValue(_FakeToolPermission());
  });

  setUp(() {
    modeDao = MockPermissionModeDao();
    ruleDao = MockToolPermissionDao();
    auth = MockAuthRepository();
    when(() => auth.currentUserId).thenReturn('user-1');
    repo = PermissionModeRepository(modeDao, ruleDao, auth);
  });

  test('watchModes sorts by name', () {
    when(() => modeDao.watch(sort: 'name'))
        .thenAnswer((_) => const Stream.empty());
    repo.watchModes();
    verify(() => modeDao.watch(sort: 'name')).called(1);
  });

  test('watchRules filters by permission_mode, sorts by tool', () {
    when(() => ruleDao.watch(
          filter: any(named: 'filter'),
          sort: any(named: 'sort'),
        )).thenAnswer((_) => const Stream.empty());
    repo.watchRules('mode-read');
    verify(() => ruleDao.watch(
          filter: 'permission_mode = "mode-read"',
          sort: 'tool',
        )).called(1);
  });

  test('saveMode sends only name/description/base_session_mode plus stamps',
      () async {
    when(() => modeDao.save(any(), any()))
        .thenAnswer((_) async => sourceMode);
    await repo.saveMode(sourceMode);
    verify(() => modeDao.save(
          sourceMode.id,
          {
            'name': 'read',
            'description': 'read-only',
            'base_session_mode': 'approve',
            'user': 'user-1',
            'is_system': false,
          },
        )).called(1);
  });

  test('deleteMode wraps failures in ToolPermissionsException', () async {
    when(() => modeDao.delete(any())).thenThrow(Exception('boom'));
    await expectLater(
      () => repo.deleteMode('mode-1'),
      throwsA(isA<ToolPermissionsException>()),
    );
  });

  test('duplicateMode copies every rule from the source onto a new mode',
      () async {
    final created = sourceMode.copyWith(id: 'mode-new', name: 'my copy');
    when(() => modeDao.save(any<String?>(), any()))
        .thenAnswer((_) async => created);
    when(() => ruleDao.getFullList(filter: any(named: 'filter')))
        .thenAnswer((_) async => [
              ToolPermission(
                id: 'rule-1',
                tool: 'bash',
                pattern: 'ls *',
                action: ToolPermissionAction.allow,
                active: true,
                permissionMode: sourceMode.id,
              ),
            ]);
    when(() => ruleDao.save(any<String?>(), any()))
        .thenAnswer((_) async => _FakeToolPermission());

    await repo.duplicateMode(source: sourceMode, newName: 'my copy');

    verify(() => ruleDao.getFullList(
          filter: 'permission_mode = "${sourceMode.id}"',
        )).called(1);
    verify(() => ruleDao.save(null, {
          'tool': 'bash',
          'pattern': 'ls *',
          'action': 'allow',
          'active': true,
          'permission_mode': 'mode-new',
        })).called(1);
  });

  test('createRule saves a new rule under the given mode', () async {
    when(() => ruleDao.save(any(), any()))
        .thenAnswer((_) async => _FakeToolPermission());
    await repo.createRule(modeId: 'mode-1', tool: 'bash', action: 'allow');
    verify(() => ruleDao.save(null, {
          'tool': 'bash',
          'pattern': '*',
          'action': 'allow',
          'active': true,
          'permission_mode': 'mode-1',
        })).called(1);
  });

  test('updateAction saves only the action field', () async {
    when(() => ruleDao.save(any(), any()))
        .thenAnswer((_) async => _FakeToolPermission());
    await repo.updateAction('rule-1', 'deny');
    verify(() => ruleDao.save('rule-1', {'action': 'deny'})).called(1);
  });

  test('setActive saves only the active field', () async {
    when(() => ruleDao.save(any(), any()))
        .thenAnswer((_) async => _FakeToolPermission());
    await repo.setActive('rule-1', false);
    verify(() => ruleDao.save('rule-1', {'active': false})).called(1);
  });
}
