import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'billing_state.dart';

@injectable
class BillingCubit extends AppCubit<BillingState> {
  final BillingService _billingService;

  BillingCubit(this._billingService) : super(const BillingState());

  Future<void> loadOffering() async {
    await tryOperation(() async {
      final package = await _billingService.getProPackage();
      final isPro = await _billingService.hasProAccess();
      return state.copyWith(
        status: UiFlowStatus.success,
        package: package,
        isPro: isPro,
        error: null,
      );
    });
  }

  Future<bool> purchasePro(String identifier) async {
    var success = false;
    await tryOperation(() async {
      success = await _billingService.purchasePro(identifier);
      if (success) {
        return state.copyWith(
          status: UiFlowStatus.success,
          isPro: true,
          error: null,
        );
      } else {
        return state.copyWith(status: UiFlowStatus.success, error: null);
      }
    });
    return success;
  }

  Future<void> restorePurchases() async {
    await tryOperation(() async {
      await _billingService.restorePurchases();
      final isPro = await _billingService.hasProAccess();
      return state.copyWith(
        status: UiFlowStatus.success,
        isPro: isPro,
        error: null,
      );
    });
  }

  Future<void> manageSubscription() async {
    await tryOperation(() async {
      await _billingService.manageSubscription();
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }
}
