import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_pro/application/server_update/server_update_cubit.dart';
import 'package:pocketcoder_pro/application/server_update/server_update_message_mapper.dart';
import 'package:pocketcoder_pro/application/server_update/server_update_state.dart';
import 'package:pocketcoder_pro/presentation/server_update/widgets/update_server_view.dart';

class UpdateServerAdapter
    extends CubitAdapter<ServerUpdateCubit, ServerUpdateState> {
  const UpdateServerAdapter({super.key, required this.instanceId});

  final String instanceId;

  static ServerUpdateState _selectState(ServerUpdateState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<ServerUpdateCubit, ServerUpdateState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<ServerUpdateCubit>();

    return UiFlowListener<ServerUpdateCubit, ServerUpdateState>(
      mapper: ServerUpdateMessageMapper(),
      child: ValueListenableBuilder<ServerUpdateState>(
        valueListenable: state,
        builder: (context, value, _) => UpdateServerView(
          isLoading: value.isLoading,
          result: value.result,
          onUpdate: () => cubit.update(instanceId),
          onDismiss: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
