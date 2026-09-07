import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/users/i_user_management_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/users/temp_password_generator.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

import 'user_management_state.dart';

@injectable
class UserManagementCubit extends AppCubit<UserManagementState> {
  final IUserManagementRepository _repository;

  UserManagementCubit(this._repository) : super(const UserManagementState());

  Future<void> loadUsers() async {
    await tryOperation(() async {
      final users = await _repository.listUsers();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        users: users,
      );
    }, emitLoading: true);
  }

  Future<String?> createUser(String email) async {
    final password = generateTempPassword();
    await tryOperation(() async {
      await _repository.createUser(email: email, password: password);
      final users = await _repository.listUsers();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        users: users,
      );
    });
    return state.status == UiFlowStatus.success ? password : null;
  }

  Future<String?> resetPassword(String userId) async {
    final password = generateTempPassword();
    await tryOperation(() async {
      await _repository.resetPassword(userId: userId, password: password);
      final users = await _repository.listUsers();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        users: users,
      );
    });
    return state.status == UiFlowStatus.success ? password : null;
  }

  Future<void> deleteUser(String userId) async {
    await tryOperation(() async {
      await _repository.deleteUser(userId);
      final users = await _repository.listUsers();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        users: users,
      );
    });
  }
}
