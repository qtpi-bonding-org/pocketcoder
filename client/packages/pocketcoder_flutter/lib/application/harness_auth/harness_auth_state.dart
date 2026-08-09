import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

class HarnessAuthState implements IUiFlowState {
  const HarnessAuthState({
    bool isLoading = false,
    this.harnesses = const <Harnesse>[],
    this.providerKeys = const <ProviderKey>[],
    this.statuses = const <String, HarnessAuthStatus>{},
    this.busyHarnesses = const <String>{},
    this.error,
  }) : _isLoading = isLoading;

  final bool _isLoading;
  final List<Harnesse> harnesses;
  final List<ProviderKey> providerKeys;
  final Map<String, HarnessAuthStatus> statuses;
  final Set<String> busyHarnesses;
  @override
  final Object? error;

  bool get isBusy => isLoading || busyHarnesses.isNotEmpty;

  bool isHarnessBusy(String harnessId) => busyHarnesses.contains(harnessId);

  HarnessAuthState copyWith({
    bool? isLoading,
    List<Harnesse>? harnesses,
    List<ProviderKey>? providerKeys,
    Map<String, HarnessAuthStatus>? statuses,
    Set<String>? busyHarnesses,
    Object? error,
    bool clearError = false,
  }) {
    return HarnessAuthState(
      isLoading: isLoading ?? _isLoading,
      harnesses: harnesses ?? this.harnesses,
      providerKeys: providerKeys ?? this.providerKeys,
      statuses: statuses ?? this.statuses,
      busyHarnesses: busyHarnesses ?? this.busyHarnesses,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool get hasError => error != null;

  @override
  UiFlowStatus get status => error != null
      ? UiFlowStatus.failure
      : (_isLoading
          ? UiFlowStatus.loading
          : (statuses.values.any((value) => value.isConnected)
              ? UiFlowStatus.success
              : UiFlowStatus.idle));

  @override
  bool get isIdle => status == UiFlowStatus.idle;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isSuccess => status == UiFlowStatus.success;

  @override
  bool get isFailure => status == UiFlowStatus.failure;
}
