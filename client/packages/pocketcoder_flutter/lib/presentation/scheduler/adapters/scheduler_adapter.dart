import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/scheduler/scheduler_cubit.dart';
import 'package:pocketcoder_flutter/application/scheduler/scheduler_state.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/scheduler/widgets/scheduler_view.dart';

class SchedulerAdapter extends CubitAdapter<SchedulerCubit, SchedulerState> {
  const SchedulerAdapter({super.key});

  static SchedulerState _selectState(SchedulerState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<SchedulerCubit, SchedulerState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<SchedulerCubit>();
    return UiFlowListener<SchedulerCubit, SchedulerState>(
      child: ValueListenableBuilder<SchedulerState>(
        valueListenable: state,
        builder: (context, value, _) => SchedulerView(
          state: value,
          onPause: cubit.pauseSchedule,
          onUnpause: cubit.unpauseSchedule,
          onRunNow: cubit.runNow,
          onDelete: cubit.deleteSchedule,
          onRename: cubit.renameSchedule,
          onUpdateCron: cubit.updateCron,
          onCreate: cubit.createSchedule,
        ),
      ),
    );
  }
}
