/// Repository abstraction for per-type notification rule preferences.
///
/// A user's rules are stored as a single PocketBase row in
/// `notification_rules` (singleton-per-user, with a `rules` JSON map of
/// `{type: bool}`). This interface exposes that row as a stream of
/// `Map<String, bool>` and lets callers toggle one key at a time.
abstract class INotificationRuleRepository {
  /// Stream of the current user's rules map. Emits `{}` when the user is
  /// unauthenticated or has no `notification_rules` row yet.
  Stream<Map<String, bool>> watchRules();

  /// Persist `enabled` for a single notification `type`, merging into the
  /// existing rules map and creating the row on first write.
  Future<void> setTypeEnabled(String type, bool enabled);
}
