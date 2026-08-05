import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';

class HarnessAuthState {
  const HarnessAuthState({
    this.isLoading = false,
    this.harnesses = const <Harnesse>[],
    this.providerKeys = const <ProviderKey>[],
    this.statuses = const <String, HarnessAuthStatus>{},
    this.busyHarnesses = const <String>{},
    this.error,
  });

  final bool isLoading;
  final List<Harnesse> harnesses;
  final List<ProviderKey> providerKeys;
  final Map<String, HarnessAuthStatus> statuses;
  final Set<String> busyHarnesses;
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
      isLoading: isLoading ?? this.isLoading,
      harnesses: harnesses ?? this.harnesses,
      providerKeys: providerKeys ?? this.providerKeys,
      statuses: statuses ?? this.statuses,
      busyHarnesses: busyHarnesses ?? this.busyHarnesses,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get hasError => error != null;
}
