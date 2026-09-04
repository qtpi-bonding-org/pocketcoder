import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/agent_config/agent_config_cubit.dart';
import 'package:pocketcoder_flutter/application/agent_config/agent_config_state.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/presentation/agent_config/widgets/agent_config_view.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

/// Top-level screen for the agent configuration UI.
///
class AgentConfigAdapter
    extends CubitAdapter<AgentConfigCubit, AgentConfigState> {
  const AgentConfigAdapter({super.key});
  static AgentConfigState _selectState(AgentConfigState state) => state;
  @override
  Widget buildAdapter(BuildContext context,
      CubitAdapterState<AgentConfigCubit, AgentConfigState> adapter) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<AgentConfigCubit>();
    return UiFlowListener<AgentConfigCubit, AgentConfigState>(
      child: ValueListenableBuilder<AgentConfigState>(
        valueListenable: state,
        builder: (context, value, _) => AgentConfigView(
          state: value,
          onSave: cubit.saveConfig,
          onDelete: cubit.deleteConfig,
        ),
      ),
    );
  }
}
