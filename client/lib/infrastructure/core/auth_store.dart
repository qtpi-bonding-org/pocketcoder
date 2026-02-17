import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';

/// Secure authentication store with persistent token storage.
///
/// Uses flutter_secure_storage for secure token persistence
/// and integrates with PocketBase auth system.
class AuthStoreConfig {
  final FlutterSecureStorage _storage;
  static const String _authKey = 'pb_auth';

  AuthStoreConfig(this._storage);

  /// Creates a SecureAuthStore that persists auth state securely.
  SecureAuthStore createAuthStore() {
    return SecureAuthStore(
      save: (String data) async {
        await _storage.write(key: _authKey, value: data);
      },
      initial: null,
      clear: () async {
        await _storage.delete(key: _authKey);
      },
    );
  }

  /// Clears authentication data (logout).
  Future<void> clear() async {
    await _storage.delete(key: _authKey);
  }

  /// Checks if auth data exists.
  Future<bool> hasAuth() async {
    return (await _storage.read(key: _authKey)) != null;
  }
}

/// Secure auth store that uses flutter_secure_storage instead of shared_preferences.
///
/// Extends $AuthStore to be compatible with pocketbase_drift's $PocketBase.database().
class SecureAuthStore extends $AuthStore {
  final bool clearOnLogout;

  SecureAuthStore({
    required super.save,
    super.initial,
    super.clear,
    this.clearOnLogout = true,
  });

  @override
  DataBase? db;

  @override
  void clear() {
    super.clear();
    if (clearOnLogout) {
      db?.clearAllData();
    }
  }
}