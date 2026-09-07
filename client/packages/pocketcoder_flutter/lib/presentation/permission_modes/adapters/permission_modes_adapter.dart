import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/permission_modes/permission_modes_cubit.dart';
import 'package:pocketcoder_flutter/application/permission_modes/permission_modes_state.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/permission_modes/permission_mode_rules_screen.dart';
import 'package:pocketcoder_flutter/presentation/permission_modes/widgets/permission_modes_view.dart';

class PermissionModesAdapter
    extends CubitAdapter<PermissionModesCubit, PermissionModesState> {
  const PermissionModesAdapter({super.key});

  static PermissionModesState _selectState(PermissionModesState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<PermissionModesCubit, PermissionModesState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<PermissionModesCubit>();
    return UiFlowListener<PermissionModesCubit, PermissionModesState>(
      child: ValueListenableBuilder<PermissionModesState>(
        valueListenable: state,
        builder: (context, value, _) => PermissionModesView(
          state: value,
          onOpenMode: (mode) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PermissionModeRulesScreen(mode: mode),
            ),
          ),
          onDuplicateMode: (source, newName) =>
              cubit.duplicateMode(source: source, newName: newName),
          onDeleteMode: cubit.deleteMode,
        ),
      ),
    );
  }
}
