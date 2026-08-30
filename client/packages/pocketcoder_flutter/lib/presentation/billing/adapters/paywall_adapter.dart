import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/application/billing/billing_cubit.dart';
import 'package:pocketcoder_flutter/application/billing/billing_state.dart';
import 'package:pocketcoder_flutter/presentation/billing/paywall_screen.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

class ProPaywallAdapter extends CubitAdapter<BillingCubit, BillingState> {
  const ProPaywallAdapter({
    super.key,
    required this.returnOnUnlock,
    required this.onOpenTermsOfService,
    required this.onOpenPrivacyPolicy,
  });

  final bool returnOnUnlock;
  final VoidCallback onOpenTermsOfService;
  final VoidCallback onOpenPrivacyPolicy;

  static BillingState _selectState(BillingState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<BillingCubit, BillingState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<BillingCubit>();
    return UiFlowListener<BillingCubit, BillingState>(
      child: ValueListenableBuilder<BillingState>(
        valueListenable: state,
        builder: (context, value, _) => PaywallView(
          state: value,
          isOnboarding: returnOnUnlock,
          onPurchase: () => _purchase(context, cubit, value),
          onRestore: () => _restore(context, cubit),
          onOpenTermsOfService: onOpenTermsOfService,
          onOpenPrivacyPolicy: onOpenPrivacyPolicy,
        ),
      ),
    );
  }

  Future<void> _purchase(
    BuildContext context,
    BillingCubit cubit,
    BillingState state,
  ) async {
    final package = state.package;
    if (package == null) return;
    final unlocked = await cubit.purchasePro(package.identifier);
    if (unlocked && context.mounted) _finishUnlock(context);
  }

  Future<void> _restore(BuildContext context, BillingCubit cubit) async {
    await cubit.restorePurchases();
    if (cubit.state.isPro && context.mounted) _finishUnlock(context);
  }

  void _finishUnlock(BuildContext context) {
    if (returnOnUnlock && context.mounted) context.pop(true);
  }
}
