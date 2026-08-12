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

  Future<void> loadOffering() async {
    emit(state.copyWith(status: UiFlowStatus.loading));
    try {
      final package = await _billingService.getProPackage();
      final isPro = await _billingService.hasProAccess();
      emit(state.copyWith(
        status: UiFlowStatus.success,
        package: package,
        isPro: isPro,
        error: null,
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

  Future<bool> purchasePro(String identifier) async {
    emit(state.copyWith(status: UiFlowStatus.loading));
    try {
      final success = await _billingService.purchasePro(identifier);
      if (success) {
        emit(state.copyWith(
          status: UiFlowStatus.success,
          isPro: true,
          error: null,
        ));
      } else {
        emit(state.copyWith(status: UiFlowStatus.success, error: null));
      }
      return success;
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
        error: e,
        source: 'BillingCubit',
        operation: 'purchase',
      );
      emit(state.copyWith(status: UiFlowStatus.failure, error: e));
      return false;
    }
  }

  Future<void> restorePurchases() async {
    emit(state.copyWith(status: UiFlowStatus.loading));
    try {
      await _billingService.restorePurchases();
      final isPro = await _billingService.hasProAccess();
      emit(state.copyWith(
        status: UiFlowStatus.success,
        isPro: isPro,
        error: null,
      ));
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
