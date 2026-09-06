/// On-device-only UI preferences -- never synced to PocketBase.
abstract class ILocalSettingsService {
  /// Synchronous, best-effort last-known value for call sites that can't
  /// await a stream (e.g. a footer-nav tap handler).
  bool get hapticsEnabledSync;

  Stream<bool> watchHapticsEnabled();
  Future<void> setHapticsEnabled(bool enabled);
}
