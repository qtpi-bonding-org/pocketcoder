import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_cubit.dart';
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_state.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/tool_permissions/widgets/tool_permissions_view.dart';

class ToolPermissionsAdapter
    extends CubitAdapter<ToolPermissionsCubit, ToolPermissionsState> {
  const ToolPermissionsAdapter({super.key});

  static ToolPermissionsState _selectState(ToolPermissionsState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<ToolPermissionsCubit, ToolPermissionsState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<ToolPermissionsCubit>();
    return UiFlowListener<ToolPermissionsCubit, ToolPermissionsState>(
      child: ValueListenableBuilder<ToolPermissionsState>(
        valueListenable: state,
        builder: (context, value, _) => ToolPermissionsView(
          state: value,
          onSetActive: cubit.setActive,
          onUpdateAction: cubit.updateAction,
          onCreateRule: (tool, action) =>
              cubit.createRule(tool: tool, action: action),
        ),
      ),
    );
  }
}
