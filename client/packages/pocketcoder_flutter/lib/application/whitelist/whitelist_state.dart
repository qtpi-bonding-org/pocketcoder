part of 'whitelist_cubit.dart';

@freezed
class WhitelistState with _$WhitelistState implements IUiFlowState {
  const WhitelistState._();

  const factory WhitelistState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<WhitelistTarget> targets,
    @Default([]) List<WhitelistAction> actions,
    Object? error,
  }) = _WhitelistState;

  factory WhitelistState.initial() => const WhitelistState();

  @override
  bool get isIdle => status == UiFlowStatus.idle;
  @override
  bool get isLoading => status == UiFlowStatus.loading;
  @override
  bool get isSuccess => status == UiFlowStatus.success;
  @override
  bool get isFailure => status == UiFlowStatus.failure;
  @override
  bool get hasError => error != null;
}
