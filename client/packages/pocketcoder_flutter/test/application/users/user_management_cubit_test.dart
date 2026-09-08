import 'package:flutter_test/flutter_test.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/users/user_management_cubit.dart';
import 'package:pocketcoder_flutter/application/users/user_management_state.dart';
import 'package:pocketcoder_flutter/domain/auth/user.dart';
import 'package:pocketcoder_flutter/domain/users/i_user_management_repository.dart';

class MockUserManagementRepository extends Mock
    implements IUserManagementRepository {}

const _user = User(id: 'u1', email: 'teammate@example.com', role: UserRole.user);

void main() {
  late MockUserManagementRepository repo;
  UserManagementCubit? lastCubit;

  UserManagementCubit buildCubit() {
    final cubit = UserManagementCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockUserManagementRepository();
  });

  tearDown(() async {
    await lastCubit?.close();
    lastCubit = null;
  });

  group('UserManagementCubit.loadUsers', () {
    test('emits loaded on success', () async {
      when(() => repo.listUsers()).thenAnswer((_) async => [_user]);

      final cubit = buildCubit();
      final states = <UserManagementState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadUsers();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states, [
        const UserManagementState(status: UiFlowStatus.loading),
        const UserManagementState(
          status: UiFlowStatus.success,
          users: [_user],
        ),
      ]);
    });
  });

  group('UserManagementCubit.createUser', () {
    test('returns the generated password on success and refreshes the list',
        () async {
      when(() => repo.createUser(
              email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => _user);
      when(() => repo.listUsers()).thenAnswer((_) async => [_user]);

      final cubit = buildCubit();
      final password = await cubit.createUser('teammate@example.com');

      expect(password, isNotNull);
      expect(password!.length, 8);
      expect(cubit.state.status, UiFlowStatus.success);
      expect(cubit.state.users, [_user]);
    });

    test('returns null on repository failure', () async {
      when(() => repo.createUser(
              email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(Exception('boom'));

      final cubit = buildCubit();
      final password = await cubit.createUser('teammate@example.com');

      expect(password, isNull);
      expect(cubit.state.hasError, isTrue);
    });
  });

  group('UserManagementCubit.resetPassword', () {
    test('returns the generated password on success', () async {
      when(() => repo.resetPassword(
              userId: any(named: 'userId'), password: any(named: 'password')))
          .thenAnswer((_) async => _user);
      when(() => repo.listUsers()).thenAnswer((_) async => [_user]);

      final cubit = buildCubit();
      final password = await cubit.resetPassword('u1');

      expect(password, isNotNull);
    });
  });

  group('UserManagementCubit.deleteUser', () {
    test('refreshes the list after delete', () async {
      when(() => repo.deleteUser('u1')).thenAnswer((_) async {});
      when(() => repo.listUsers()).thenAnswer((_) async => []);

      final cubit = buildCubit();
      await cubit.deleteUser('u1');

      expect(cubit.state.status, UiFlowStatus.success);
      expect(cubit.state.users, isEmpty);
    });
  });
}
