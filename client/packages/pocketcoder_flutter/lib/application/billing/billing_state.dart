import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import '../../domain/billing/billing_service.dart';

part 'billing_state.freezed.dart';

@freezed
class BillingState with _$BillingState implements IUiFlowState {
  const BillingState._();

  const factory BillingState({
    @Default([]) List<BillingPackage> packages,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default(false) bool isPremium,
    Object? error,
  }) = _BillingState;

  @override
  bool get isLoading => status == UiFlowStatus.loading;

  @override
  bool get isSuccess => status == UiFlowStatus.success;

  @override
  bool get isFailure => status == UiFlowStatus.failure;

  @override
  bool get isIdle => status == UiFlowStatus.idle;

  @override
  bool get hasError => error != null;
}
