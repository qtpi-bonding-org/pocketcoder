import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class FossRootSshCredentials {
  const FossRootSshCredentials({
    required this.publicKey,
    required this.privateKey,
    required this.hostKeyType,
    required this.hostKeyFingerprint,
  });

  final String publicKey;
  final String privateKey;
  final String hostKeyType;
  final String hostKeyFingerprint;

  Map<String, Object?> toJson() => {
        'publicKey': publicKey,
        'privateKey': privateKey,
        'hostKeyType': hostKeyType,
        'hostKeyFingerprint': hostKeyFingerprint,
      };

  static FossRootSshCredentials? tryParse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return null;
      final publicKey = json['publicKey'];
      final privateKey = json['privateKey'];
      final hostKeyType = json['hostKeyType'];
      final hostKeyFingerprint = json['hostKeyFingerprint'];
      if (publicKey is! String ||
          privateKey is! String ||
          hostKeyType is! String ||
          hostKeyFingerprint is! String) {
        return null;
      }
      return FossRootSshCredentials(
        publicKey: publicKey,
        privateKey: privateKey,
        hostKeyType: hostKeyType,
        hostKeyFingerprint: hostKeyFingerprint,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FossRootSshCredentials &&
      other.publicKey == publicKey &&
      other.privateKey == privateKey &&
      other.hostKeyType == hostKeyType &&
      other.hostKeyFingerprint == hostKeyFingerprint;

  @override
  int get hashCode =>
      Object.hash(publicKey, privateKey, hostKeyType, hostKeyFingerprint);
}

// Stored as one serialized value, not one key per field, so a write either
// fully lands or fully doesn't.
class FossRootSshCredentialsStore {
  FossRootSshCredentialsStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'foss.root_ssh.credentials';

  Future<void> save(FossRootSshCredentials credentials) =>
      _storage.write(key: _key, value: jsonEncode(credentials.toJson()));

  Future<FossRootSshCredentials?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return FossRootSshCredentials.tryParse(raw);
  }

  Future<void> clear() => _storage.delete(key: _key);
}
