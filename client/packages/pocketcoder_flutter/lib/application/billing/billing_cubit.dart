import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import '../../domain/billing/billing_service.dart';
import 'billing_state.dart';

@injectable
class BillingCubit extends Cubit<BillingState> {
  final BillingService _billingService;

  BillingCubit(this._billingService) : super(const BillingState());

  Future<void> loadOfferings() async {
    emit(state.copyWith(status: UiFlowStatus.loading));
    try {
      final packages = await _billingService.getAvailablePackages();
      final isPremium = await _billingService.isPremium();
      emit(state.copyWith(
        status: UiFlowStatus.success,
        packages: packages,
        isPremium: isPremium,
      ));
    } catch (e) {
      emit(state.copyWith(status: UiFlowStatus.failure, error: e));
    }
  }

  Future<void> purchase(String identifier) async {
    emit(state.copyWith(status: UiFlowStatus.loading));
    try {
      final success = await _billingService.purchase(identifier);
      if (success) {
        emit(state.copyWith(status: UiFlowStatus.success, isPremium: true));
      } else {
        emit(state.copyWith(
            status: UiFlowStatus.failure, error: 'Purchase failed'));
      }
    } catch (e) {
      emit(state.copyWith(status: UiFlowStatus.failure, error: e));
    }
  }

  Future<void> restorePurchases() async {
    emit(state.copyWith(status: UiFlowStatus.loading));
    try {
      await _billingService.restorePurchases();
      final isPremium = await _billingService.isPremium();
      emit(state.copyWith(status: UiFlowStatus.success, isPremium: isPremium));
    } catch (e) {
      emit(state.copyWith(status: UiFlowStatus.failure, error: e));
    }
  }
}
