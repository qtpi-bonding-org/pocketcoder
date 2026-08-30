/// Purges PocketCoder-Pro-hosted data only -- never this deployment's own
/// local PocketBase data, which the user already owns and controls.
abstract class ProDataDeletionHook {
  Future<void> deleteProData();
}

class NoopProDataDeletionHook implements ProDataDeletionHook {
  const NoopProDataDeletionHook();

  @override
  Future<void> deleteProData() async {}
}
