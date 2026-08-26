import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/observability/observability_cubit.dart';
import 'package:pocketcoder_flutter/application/observability/observability_state.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/monitor/monitor_screen.dart';

class MonitorAdapter
    extends CubitAdapter<ObservabilityCubit, ObservabilityState> {
  const MonitorAdapter({super.key});

  static ObservabilityState _selectState(ObservabilityState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<ObservabilityCubit, ObservabilityState> adapter,
  ) {
    adapter.keep<bool>('observabilityStarted', () {
      adapter.cubit
        ..refreshStats()
        ..loadContainers();
      return true;
    });
    final cubit = context.read<ObservabilityCubit>();
    final state = adapter.cubitField(_selectState);
    return UiFlowListener<ObservabilityCubit, ObservabilityState>(
      child: ValueListenableBuilder<ObservabilityState>(
        valueListenable: state,
        builder: (context, value, _) => MonitorView(
          state: value,
          onRefresh: () {
            cubit.refreshStats();
            cubit.loadContainers();
          },
          onSelectContainer: (container) {
            if (container == null) {
              cubit.stopLogStreaming();
            } else {
              cubit.startLogStreaming(container);
            }
          },
        ),
      ),
    );
  }
}
