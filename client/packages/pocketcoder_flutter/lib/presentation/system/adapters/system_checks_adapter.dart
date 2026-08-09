import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/system/health_cubit.dart';
import 'package:pocketcoder_flutter/application/system/health_state.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/system/system_checks_screen.dart';

class SystemChecksAdapter extends CubitAdapter<HealthCubit, HealthState> {
  const SystemChecksAdapter({super.key});

  static HealthState _selectState(HealthState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<HealthCubit, HealthState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    return UiFlowListener<HealthCubit, HealthState>(
      child: ValueListenableBuilder<HealthState>(
        valueListenable: state,
        builder: (context, value, _) => SystemChecksView(
          state: value,
          onRefresh: context.read<HealthCubit>().refresh,
        ),
      ),
    );
  }
}
