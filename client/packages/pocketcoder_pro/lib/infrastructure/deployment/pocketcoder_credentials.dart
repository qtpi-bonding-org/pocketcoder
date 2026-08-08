import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PocketCoderCredentials {
  const PocketCoderCredentials({
    required this.instanceId,
    required this.adminEmail,
    required this.adminPassword,
  });

  final String instanceId;
  final String adminEmail;
  final String adminPassword;
}

class PocketCoderCredentialStore {
  PocketCoderCredentialStore(this._storage);

  final FlutterSecureStorage _storage;

  String _key(String instanceId, String field) =>
      'pocketcoder_credentials_${instanceId}_$field';

  Future<void> store(PocketCoderCredentials credentials) async {
    await Future.wait([
      _storage.write(
        key: _key(credentials.instanceId, 'email'),
        value: credentials.adminEmail,
      ),
      _storage.write(
        key: _key(credentials.instanceId, 'password'),
        value: credentials.adminPassword,
      ),
    ]);
  }

  Future<PocketCoderCredentials?> get(String instanceId) async {
    final values = await Future.wait([
      _storage.read(key: _key(instanceId, 'email')),
      _storage.read(key: _key(instanceId, 'password')),
    ]);
    final email = values[0];
    final password = values[1];
    if (email == null || password == null) return null;
    return PocketCoderCredentials(
      instanceId: instanceId,
      adminEmail: email,
      adminPassword: password,
    );
  }
}
