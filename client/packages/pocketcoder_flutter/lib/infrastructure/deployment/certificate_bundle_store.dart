import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketcoder_flutter/domain/deployment/certificate_bundle.dart';

final class CertificateBundleStore {
  const CertificateBundleStore(this._storage);

  final FlutterSecureStorage _storage;

  Future<void> write({
    required String deploymentId,
    required CertificateBundle bundle,
  }) {
    return _storage.write(
      key: _key(deploymentId, bundle.hostname),
      value: jsonEncode(bundle.toJson()),
    );
  }

  Future<CertificateBundle?> read({
    required String deploymentId,
    required String hostname,
  }) async {
    final value = await _storage.read(key: _key(deploymentId, hostname));
    if (value == null) return null;
    try {
      final bundle = CertificateBundle.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
      return bundle.hostname == hostname ? bundle : null;
    } on Object {
      return null;
    }
  }

  static String _key(String deploymentId, String hostname) =>
      'pocketcoder.caddy-certificate.$deploymentId.$hostname';
}
