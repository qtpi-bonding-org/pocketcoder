import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/auth/user.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/users/i_user_management_repository.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/infrastructure/users/user_dao.dart';

@LazySingleton(as: IUserManagementRepository)
class UserManagementRepository implements IUserManagementRepository {
  final UserDao _dao;

  UserManagementRepository(this._dao);

  @override
  Future<List<User>> listUsers() async {
    return tryMethod(
      () async => _dao.getFullList(filter: "role != 'admin'", sort: 'email'),
      UserManagementException.new,
      'listUsers',
    );
  }

  @override
  Future<User> createUser({
    required String email,
    required String password,
  }) async {
    return tryMethod(
      () async => _dao.save(null, <String, dynamic>{
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'role': 'user',
        'verified': true,
      }),
      UserManagementException.new,
      'createUser',
    );
  }

  @override
  Future<User> resetPassword({
    required String userId,
    required String password,
  }) async {
    return tryMethod(
      () async => _dao.save(userId, {
        'password': password,
        'passwordConfirm': password,
      }),
      UserManagementException.new,
      'resetPassword',
    );
  }

  @override
  Future<void> deleteUser(String userId) async {
    return tryMethod(
      () async => _dao.delete(userId),
      UserManagementException.new,
      'deleteUser',
    );
  }
}
