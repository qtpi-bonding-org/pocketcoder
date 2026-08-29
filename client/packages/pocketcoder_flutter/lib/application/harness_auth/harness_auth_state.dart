import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'harness_auth_state.freezed.dart';

/// Identifies an OAuth connection without conflating providers on the same
/// harness.
class HarnessProviderKey {
  const HarnessProviderKey(this.harness, this.provider);

  final String harness;
  final String provider;

  @override
  bool operator ==(Object other) =>
      other is HarnessProviderKey &&
      other.harness == harness &&
      other.provider == provider;

  @override
  int get hashCode => Object.hash(harness, provider);
}

@freezed
sealed class HarnessAuthState with _$HarnessAuthState, UiFlowStateMixin {
  const HarnessAuthState._();

  const factory HarnessAuthState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default(<Harnesse>[]) List<Harnesse> harnesses,
    @Default(<HarnessProvider>[]) List<HarnessProvider> harnessProviders,
    @Default(<HarnessProviderKey, HarnessAuthStatus>{})
    Map<HarnessProviderKey, HarnessAuthStatus> statuses,
    @Default(<HarnessProviderKey>{}) Set<HarnessProviderKey> busyHarnesses,
    @Default(false) bool harnessProvidersLoaded,
    Object? error,
  }) = _HarnessAuthState;

  bool get isBusy => status == UiFlowStatus.loading || busyHarnesses.isNotEmpty;

  bool isHarnessBusy(String harnessId, [String? provider]) =>
      busyHarnesses.any((key) =>
          key.harness == harnessId &&
          (provider == null || key.provider == provider));

  HarnessAuthStatus? statusFor(String harnessId, String provider) =>
      statuses[HarnessProviderKey(harnessId, provider)];
}
