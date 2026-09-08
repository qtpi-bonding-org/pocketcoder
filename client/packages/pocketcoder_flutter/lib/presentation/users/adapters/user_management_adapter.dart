import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/users/user_management_cubit.dart';
import 'package:pocketcoder_flutter/application/users/user_management_state.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/users/widgets/user_management_view.dart';

class UserManagementAdapter
    extends CubitAdapter<UserManagementCubit, UserManagementState> {
  const UserManagementAdapter({super.key});

  static UserManagementState _selectState(UserManagementState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<UserManagementCubit, UserManagementState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<UserManagementCubit>();
    return UiFlowListener<UserManagementCubit, UserManagementState>(
      child: ValueListenableBuilder<UserManagementState>(
        valueListenable: state,
        builder: (context, value, _) => UserManagementView(
          state: value,
          onCreate: cubit.createUser,
          onResetPassword: cubit.resetPassword,
          onDelete: cubit.deleteUser,
        ),
      ),
    );
  }
}
