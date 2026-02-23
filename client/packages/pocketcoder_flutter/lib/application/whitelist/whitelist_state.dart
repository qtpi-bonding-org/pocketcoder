part of 'whitelist_cubit.dart';

@freezed
class WhitelistState with _$WhitelistState {
  const factory WhitelistState.initial() = _Initial;
  const factory WhitelistState.loading() = _Loading;
  const factory WhitelistState.loaded({
    required List<WhitelistTarget> targets,
    required List<WhitelistAction> actions,
  }) = _Loaded;
  const factory WhitelistState.error(String message) = _Error;
}
