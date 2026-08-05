import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'billing_state.dart';

@injectable
class BillingCubit extends Cubit<BillingState> {
  final BillingService _billingService;

  BillingCubit(this._billingService) : super(const BillingState());

  Future<void> loadOfferings() async {
    emit(state.copyWith(status: UiFlowStatus.loading));
    try {
      final packages = await _billingService.getAvailablePackages();
      final isPro = await _billingService.isPro();
      emit(state.copyWith(
        status: UiFlowStatus.success,
        packages: packages,
        isPro: isPro,
      ));
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
        error: e,
        source: 'BillingCubit',
        operation: 'loadOfferings',
      );
      emit(state.copyWith(status: UiFlowStatus.failure, error: e));
    }
  }

  Future<void> purchase(String identifier) async {
    emit(state.copyWith(status: UiFlowStatus.loading));
    try {
      final success = await _billingService.purchase(identifier);
      if (success) {
        emit(state.copyWith(status: UiFlowStatus.success, isPro: true));
      } else {
        emit(state.copyWith(
            status: UiFlowStatus.failure, error: 'Purchase failed'));
      }
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
        error: e,
        source: 'BillingCubit',
        operation: 'purchase',
      );
      emit(state.copyWith(status: UiFlowStatus.failure, error: e));
    }
  }

  Future<void> restorePurchases() async {
    emit(state.copyWith(status: UiFlowStatus.loading));
    try {
      await _billingService.restorePurchases();
      final isPro = await _billingService.isPro();
      emit(state.copyWith(status: UiFlowStatus.success, isPro: isPro));
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
        error: e,
        source: 'BillingCubit',
        operation: 'restorePurchases',
      );
      emit(state.copyWith(status: UiFlowStatus.failure, error: e));
    }
  }
}
