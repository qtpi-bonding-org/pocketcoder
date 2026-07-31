import 'package:shared_preferences/shared_preferences.dart';

/// Persists which Linode instance ID is "the" deployment this device
/// provisioned, so the update feature can be reached later (e.g. from
/// Settings, days after deploying) without needing to pass instanceId
/// through the whole navigation stack. Not secret -- an instance ID alone
/// grants nothing; the actual root credentials stay in ISecureStorage,
/// keyed by this same ID.
class CurrentInstanceStore {
  static const _key = 'pocketcoder_current_instance_id';

  Future<void> save(String instanceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, instanceId);
  }

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }
}
