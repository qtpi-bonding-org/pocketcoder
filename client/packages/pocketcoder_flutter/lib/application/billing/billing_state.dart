import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';

part 'billing_state.freezed.dart';

@freezed
sealed class BillingState with _$BillingState implements IUiFlowState {
  const BillingState._();

  const factory BillingState({
    BillingPackage? package,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default(false) bool isPro,
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
