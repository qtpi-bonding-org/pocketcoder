import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketcoder_flutter/domain/deployment/caddy_ca_pin.dart';

final class CaddyCaPinStore {
  const CaddyCaPinStore(this._storage);

  final FlutterSecureStorage _storage;

  Future<void> write({required String deploymentId, required CaddyCaPin pin}) {
    return _storage.write(
      key: _key(deploymentId),
      value: jsonEncode(pin.toJson()),
    );
  }

  Future<CaddyCaPin?> read({required String deploymentId}) async {
    final value = await _storage.read(key: _key(deploymentId));
    if (value == null) return null;
    try {
      return CaddyCaPin.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> clear(String deploymentId) =>
      _storage.delete(key: _key(deploymentId));

  static String _key(String deploymentId) =>
      'pocketcoder.caddy-ca-pin.$deploymentId';
}
