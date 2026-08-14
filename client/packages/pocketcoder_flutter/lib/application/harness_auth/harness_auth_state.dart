import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'harness_auth_state.freezed.dart';

@freezed
sealed class HarnessAuthState with _$HarnessAuthState, UiFlowStateMixin {
  const HarnessAuthState._();

  const factory HarnessAuthState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default(<Harnesse>[]) List<Harnesse> harnesses,
    @Default(<ProviderKey>[]) List<ProviderKey> providerKeys,
    @Default(<String, HarnessAuthStatus>{})
    Map<String, HarnessAuthStatus> statuses,
    @Default(<String>{}) Set<String> busyHarnesses,
    Object? error,
  }) = _HarnessAuthState;

  bool get isBusy => status == UiFlowStatus.loading || busyHarnesses.isNotEmpty;

  bool isHarnessBusy(String harnessId) => busyHarnesses.contains(harnessId);
}
