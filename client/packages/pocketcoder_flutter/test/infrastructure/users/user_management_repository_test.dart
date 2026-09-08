import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/auth/user.dart';
import 'package:pocketcoder_flutter/infrastructure/users/user_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/users/user_management_repository.dart';

class MockUserDao extends Mock implements UserDao {}

const _user = User(id: 'u1', email: 'teammate@example.com', role: UserRole.user);

void main() {
  late MockUserDao dao;
  late UserManagementRepository repository;

  setUp(() {
    dao = MockUserDao();
    repository = UserManagementRepository(dao);
  });

  test('listUsers excludes admins via a server-side filter', () async {
    when(() => dao.getFullList(filter: "role != 'admin'", sort: 'email'))
        .thenAnswer((_) async => [_user]);

    expect(await repository.listUsers(), [_user]);
  });

  test('createUser sends matching password/passwordConfirm and fixed role',
      () async {
    when(() => dao.save(any<String?>(), any<Map<String, dynamic>>()))
        .thenAnswer((_) async => _user);

    await repository.createUser(email: 'teammate@example.com', password: 'Ab2cdEfg');

    final body = verify(() => dao.save(
          any<String?>(),
          captureAny<Map<String, dynamic>>(),
        )).captured.single as Map;
    expect(body['email'], 'teammate@example.com');
    expect(body['password'], 'Ab2cdEfg');
    expect(body['passwordConfirm'], 'Ab2cdEfg');
    expect(body['role'], 'user');
    expect(body['verified'], true);
  });

  test('resetPassword sends matching password/passwordConfirm to that id',
      () async {
    when(() => dao.save('u1', any())).thenAnswer((_) async => _user);

    await repository.resetPassword(userId: 'u1', password: 'Xy9zAbCd');

    final body =
        verify(() => dao.save('u1', captureAny())).captured.single as Map;
    expect(body['password'], 'Xy9zAbCd');
    expect(body['passwordConfirm'], 'Xy9zAbCd');
  });

  test('deleteUser deletes through the DAO', () async {
    when(() => dao.delete('u1')).thenAnswer((_) async {});

    await repository.deleteUser('u1');

    verify(() => dao.delete('u1')).called(1);
  });
}
