/// The ordered set of user-meaningful steps the deployed server passes
/// through during first-boot install. Declaration order below is the
/// canonical sequence -- there is no separate order list to keep in sync;
/// `DeployOperationKey.values` IS the contract.
///
/// `waitingForConnection` and `ready` never appear on the wire: the former
/// is the state before any status document has been successfully parsed,
/// the latter is inferred client-side from `/api/health` returning 200.
enum DeployOperationKey {
  waitingForConnection,
  configuringOperatingSystem,
  fetchingRelease,
  loadingImages,
  composeUp,
  bootstrapComplete,
  ready,
}

extension DeployOperationKeyX on DeployOperationKey {
  /// Maps a wire value to its operation key. Returns null -- not a
  /// default -- for anything unrecognized or absent, so the caller can
  /// hold its previous key instead of silently regressing to one.
  static DeployOperationKey? fromWireName(String? wire) => switch (wire) {
    'configuring_operating_system' => DeployOperationKey.configuringOperatingSystem,
    'fetching_release' => DeployOperationKey.fetchingRelease,
    'loading_images' => DeployOperationKey.loadingImages,
    'compose_up' => DeployOperationKey.composeUp,
    'bootstrap_complete' => DeployOperationKey.bootstrapComplete,
    _ => null,
  };
}
