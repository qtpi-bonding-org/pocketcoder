import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketcoder_flutter/application/billing/billing_cubit.dart';
import 'package:pocketcoder_flutter/application/billing/billing_state.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/presentation/billing/permission_relay_screen.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

class PermissionRelayAdapter
    extends CubitAdapter<BillingCubit, BillingState> {
  const PermissionRelayAdapter({super.key});

  static BillingState _selectState(BillingState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<BillingCubit, BillingState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    return UiFlowListener<BillingCubit, BillingState>(
      child: ValueListenableBuilder<BillingState>(
        valueListenable: state,
        builder: (context, value, _) => PermissionRelayView(
          state: value,
          onRestore: context.read<BillingCubit>().restorePurchases,
          onPurchase: context.read<BillingCubit>().purchase,
          onConfigure: GetIt.I<PushService>().configure,
        ),
      ),
    );
  }
}
