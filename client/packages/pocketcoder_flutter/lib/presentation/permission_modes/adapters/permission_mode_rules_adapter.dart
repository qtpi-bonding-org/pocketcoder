import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/permission_modes/permission_mode_rules_cubit.dart';
import 'package:pocketcoder_flutter/application/permission_modes/permission_mode_rules_state.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/permission_modes/widgets/permission_mode_rules_view.dart';

class PermissionModeRulesAdapter
    extends CubitAdapter<PermissionModeRulesCubit, PermissionModeRulesState> {
  const PermissionModeRulesAdapter({super.key, required this.mode});

  final PermissionMode mode;

  static PermissionModeRulesState _selectState(
          PermissionModeRulesState state) =>
      state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<PermissionModeRulesCubit, PermissionModeRulesState>
        adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<PermissionModeRulesCubit>();
    return UiFlowListener<PermissionModeRulesCubit, PermissionModeRulesState>(
      child: ValueListenableBuilder<PermissionModeRulesState>(
        valueListenable: state,
        builder: (context, value, _) => PermissionModeRulesView(
          title: mode.name,
          readOnly: mode.isSystem == true,
          state: value,
          onSetActive: cubit.setActive,
          onUpdateAction: cubit.updateAction,
          onCreateRule: (tool, action) =>
              cubit.createRule(modeId: mode.id, tool: tool, action: action),
        ),
      ),
    );
  }
}
