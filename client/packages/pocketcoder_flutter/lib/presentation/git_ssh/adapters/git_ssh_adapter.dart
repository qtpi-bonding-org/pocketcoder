import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/git_ssh/git_ssh_cubit.dart';
import 'package:pocketcoder_flutter/application/git_ssh/git_ssh_state.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/git_ssh/widgets/git_ssh_view.dart';

class GitSshAdapter extends CubitAdapter<GitSshCubit, GitSshState> {
  const GitSshAdapter({super.key});

  static GitSshState _selectState(GitSshState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<GitSshCubit, GitSshState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<GitSshCubit>();
    return UiFlowListener<GitSshCubit, GitSshState>(
      child: ValueListenableBuilder<GitSshState>(
        valueListenable: state,
        builder: (context, value, _) => GitSshView(
          state: value,
          onCreateAccountKey: cubit.createAccountKey,
          onAddRepositoryAccess: cubit.addRepositoryAccess,
          onDeleteAccess: cubit.deleteAccess,
        ),
      ),
    );
  }
}
