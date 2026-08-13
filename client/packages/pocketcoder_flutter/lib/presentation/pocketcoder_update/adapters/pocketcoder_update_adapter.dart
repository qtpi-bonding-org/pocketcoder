import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/application/pocketcoder_update/pocketcoder_update_cubit.dart';
import 'package:pocketcoder_flutter/application/pocketcoder_update/pocketcoder_update_message_mapper.dart';
import 'package:pocketcoder_flutter/application/pocketcoder_update/pocketcoder_update_state.dart';
import 'package:pocketcoder_flutter/presentation/pocketcoder_update/widgets/pocketcoder_update_view.dart';

class PocketCoderUpdateAdapter
    extends CubitAdapter<PocketCoderUpdateCubit, PocketCoderUpdateState> {
  const PocketCoderUpdateAdapter({super.key, required this.instanceId});

  final String instanceId;

  static PocketCoderUpdateState _selectState(PocketCoderUpdateState state) =>
      state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<PocketCoderUpdateCubit, PocketCoderUpdateState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<PocketCoderUpdateCubit>();

    return UiFlowListener<PocketCoderUpdateCubit, PocketCoderUpdateState>(
      mapper: PocketCoderUpdateMessageMapper(),
      child: ValueListenableBuilder<PocketCoderUpdateState>(
        valueListenable: state,
        builder: (context, value, _) => PocketCoderUpdateView(
          isLoading: value.isLoading,
          preview: value.preview,
          result: value.result,
          onRefresh: cubit.load,
          onUpdate: value.preview?.crossesDataVersion == true &&
                  !value.upgradeConfirmed
              ? cubit.confirmUpgrade
              : () => cubit.update(instanceId),
          upgradeConfirmed: value.upgradeConfirmed,
          onDismiss: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
