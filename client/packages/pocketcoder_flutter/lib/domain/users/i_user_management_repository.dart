import 'package:pocketcoder_flutter/domain/auth/user.dart';

abstract class IUserManagementRepository {
  Future<List<User>> listUsers();
  Future<User> createUser({required String email, required String password});
  Future<User> resetPassword({required String userId, required String password});
  Future<void> deleteUser(String userId);
}
